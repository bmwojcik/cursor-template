<?php
/**
 * Static DI / plugin scan for custom Magento 2 code. Reads files only; never boots Magento.
 *
 * Run inside the PHP container (needs ext-simplexml and the project's vendor/composer maps).
 * The script can be piped through stdin, so it does not have to live inside the mounted tree:
 *
 *   <container php> -d memory_limit=2G -- <magento-root> [--roots=Vendor1,Vendor2] [--package=vendor/name] < magento2-di-scan.php
 *
 * --roots    Vendor directories under app/code to scan (default: every dir under app/code except Magento).
 * --package  Composer package being upgraded. Limits findings to references into its PSR-4/PSR-0 namespaces.
 *
 * Findings (tab separated: KIND, reference, where):
 *   MISSING_CLASS            a class/interface named in a constructor, di.xml or events.xml does not exist
 *   INTERFACE_NO_PREFERENCE  a required constructor argument is an interface with no <preference> anywhere
 *   PLUGIN_TARGET_MISSING    the <type name> a plugin is declared on does not exist
 *   PLUGIN_METHOD_NO_TARGET  before/after/around method whose target method does not exist (plugin never runs)
 *   PLUGIN_METHOD_ON_IFACE   same, but the target is an interface: verify on the implementation by hand
 * Exit code 1 when anything except PLUGIN_METHOD_ON_IFACE is found.
 */

$args = array_values(array_filter(array_slice($argv, 1), fn ($a) => $a !== '--'));
$root = null;
$opts = ['roots' => '', 'package' => ''];
foreach ($args as $a) {
    if (preg_match('/^--(roots|package)=(.*)$/', $a, $m)) {
        $opts[$m[1]] = $m[2];
    } elseif ($root === null) {
        $root = rtrim($a, '/');
    }
}
if (!$root || !is_file("$root/vendor/composer/ClassLoader.php")) {
    fwrite(fopen("php://stderr", "w"), "usage: php -- <magento-root> [--roots=A,B] [--package=vendor/name] < magento2-di-scan.php\n");
    exit(2);
}
if (!function_exists('simplexml_load_file')) {
    fwrite(fopen("php://stderr", "w"), "ext-simplexml missing: run this inside the PHP container\n");
    exit(2);
}

// Composer maps without vendor/autoload.php: no platform check, no autoload "files" executed.
require "$root/vendor/composer/ClassLoader.php";
$loader = new Composer\Autoload\ClassLoader("$root/vendor");
foreach (require "$root/vendor/composer/autoload_namespaces.php" as $ns => $p) $loader->set($ns, $p);
foreach (require "$root/vendor/composer/autoload_psr4.php" as $ns => $p) $loader->setPsr4($ns, $p);
$loader->addClassMap(require "$root/vendor/composer/autoload_classmap.php");

$config = is_file("$root/app/etc/config.php") ? include "$root/app/etc/config.php" : ['modules' => []];
$disabled = array_keys(array_filter($config['modules'] ?? [], fn ($v) => !$v));

$roots = $opts['roots'] !== ''
    ? array_map('trim', explode(',', $opts['roots']))
    : array_values(array_filter(array_map('basename', glob("$root/app/code/*", GLOB_ONLYDIR) ?: []), fn ($d) => $d !== 'Magento'));

// Namespaces of the upgraded package, used only to filter findings.
$pkgNamespaces = [];
if ($opts['package'] !== '') {
    $pj = "$root/vendor/{$opts['package']}/composer.json";
    if (!is_file($pj)) {
        fwrite(fopen("php://stderr", "w"), "package {$opts['package']} not found under vendor/\n");
        exit(2);
    }
    $autoload = json_decode(file_get_contents($pj), true)['autoload'] ?? [];
    foreach (['psr-4', 'psr-0'] as $kind) {
        foreach (array_keys($autoload[$kind] ?? []) as $ns) $pkgNamespaces[] = rtrim($ns, '\\') . '\\';
    }
}
function inPackage(string $cls, array $nss): bool
{
    if (!$nss) return true;
    foreach ($nss as $ns) if (str_starts_with(ltrim($cls, '\\') . '\\', $ns)) return true;
    return false;
}

function rglob(string $dir, string $pattern): array
{
    if (!is_dir($dir)) return [];
    $out = [];
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $f) if (fnmatch($pattern, $f->getFilename())) $out[] = $f->getPathname();
    return $out;
}
function moduleOf(string $path, string $root): string
{
    return implode('_', array_slice(explode('/', substr($path, strlen("$root/app/code/"))), 0, 2));
}
function fileFor($loader, string $cls, string $root): ?string
{
    $cls = ltrim($cls, '\\');
    $f = $loader->findFile($cls);
    if ($f) return $f;
    $p = "$root/app/code/" . str_replace('\\', '/', $cls) . '.php';
    return is_file($p) ? $p : null;
}
function isInterface(string $file, string $cls): bool
{
    $short = substr($cls, strrpos($cls, '\\') + 1);
    return (bool)preg_match('/^\s*interface\s+' . preg_quote($short, '/') . '\b/m', file_get_contents($file));
}
function resolveName(string $name, string $src): string
{
    if ($name[0] === '\\') return substr($name, 1);
    preg_match('/^namespace\s+([^;]+);/m', $src, $ns);
    preg_match_all('/^use\s+([^;{]+?)(?:\s+as\s+(\w+))?;/m', $src, $um, PREG_SET_ORDER);
    $first = explode('\\', $name)[0];
    foreach ($um as $u) {
        $fq = trim($u[1]);
        $alias = !empty($u[2]) ? $u[2] : substr($fq, strrpos($fq, '\\') + 1);
        if ($alias === $first) return $fq . substr($name, strlen($first));
    }
    return trim($ns[1] ?? '') . '\\' . $name;
}
/** Public method names of a class/interface including parents, interfaces and traits; null when missing. */
function methodsOf($loader, string $root, string $cls, array &$seen = []): ?array
{
    $cls = ltrim($cls, '\\');
    if (isset($seen[$cls])) return [];
    $seen[$cls] = true;
    $f = fileFor($loader, $cls, $root);
    if (!$f) return null;
    $src = file_get_contents($f);
    preg_match_all('/public\s+(?:static\s+)?function\s+&?\s*(\w+)\s*\(/', $src, $m);
    preg_match_all('/^\s*(?:abstract\s+)?function\s+(\w+)\s*\(/m', $src, $m2);
    $methods = array_map('strtolower', array_merge($m[1], $m2[1]));
    $short = substr($cls, strrpos($cls, '\\') + 1);
    $parents = [];
    if (preg_match('/(?:class|interface)\s+' . preg_quote($short, '/') . '\s+(?:extends\s+([\\\\\w,\s]+?))?\s*(?:implements\s+([\\\\\w,\s]+?))?\s*\{/s', $src, $h)) {
        foreach ([$h[1] ?? '', $h[2] ?? ''] as $list) {
            foreach (array_filter(array_map('trim', explode(',', $list))) as $p) $parents[] = resolveName($p, $src);
        }
    }
    if (preg_match('/\{(.*)$/s', $src, $body) && preg_match_all('/^\s*use\s+([\\\\\w]+)\s*;/m', $body[1], $tm)) {
        foreach ($tm[1] as $t) $parents[] = resolveName($t, $src);
    }
    foreach ($parents as $p) {
        $pm = methodsOf($loader, $root, $p, $seen);
        if ($pm) $methods = array_merge($methods, $pm);
    }
    if (preg_match('/function\s+__call\s*\(/', $src)) $methods[] = '*';
    return $methods;
}

// Every <preference for> and <virtualType> in the codebase.
$prefs = [];
$virtual = [];
$configuredArgs = [];
foreach (array_merge(rglob("$root/vendor", 'di.xml'), rglob("$root/app/code", 'di.xml'), ["$root/app/etc/di.xml"]) as $f) {
    if (preg_match('#/(Test|tests)/#', $f)) continue;
    $x = @simplexml_load_file($f);
    if (!$x) continue;
    foreach ($x->xpath('//preference') as $p) $prefs[ltrim((string)$p['for'], '\\')] = true;
    foreach ($x->xpath('//virtualType') as $v) $virtual[ltrim((string)$v['name'], '\\')] = true;
    // Constructor arguments given explicitly in DI (on the class itself or on a virtualType built from it).
    foreach ($x->xpath('//type|//virtualType') as $t) {
        $cls = ltrim((string)($t->getName() === 'virtualType' ? $t['type'] : $t['name']), '\\');
        foreach ($t->xpath('arguments/argument') as $a) $configuredArgs[$cls][(string)$a['name']] = true;
    }
}
// Wired by the framework itself, or always passed explicitly by a factory create([...]) call.
$prefs['Magento\Framework\ObjectManagerInterface'] = true;
$prefs['Magento\Framework\Pricing\SaleableInterface'] = true;

$findings = [];
$add = function (string $kind, string $ref, string $where) use (&$findings, $pkgNamespaces) {
    if (!inPackage($ref, $pkgNamespaces)) return;
    $findings["$kind\t$ref\t$where"] = $kind;
};
/** $needsImpl: the reference must be instantiable (constructor argument), so an interface needs a preference. */
$check = function (string $cls, string $where, bool $needsImpl) use ($loader, $root, $prefs, $virtual, $add) {
    $cls = ltrim(trim($cls), '\\');
    if ($cls === '' || isset($virtual[$cls]) || !preg_match('/^[A-Za-z_][\w\\\\]*$/', $cls)) return;
    $base = $cls;
    if (!fileFor($loader, $cls, $root) && preg_match('/^(.*?)(Factory|\\\\Proxy)$/', $cls, $m)) $base = $m[1];
    if (isset($virtual[$base]) || preg_match('/(ExtensionInterface|Extension)$/', $base)) return; // generated
    $f = fileFor($loader, $base, $root);
    if (!$f) {
        $add('MISSING_CLASS', $cls, $where);
        return;
    }
    if ($needsImpl && isInterface($f, $base) && empty($prefs[$base])) $add('INTERFACE_NO_PREFERENCE', $cls, $where);
};

foreach ($roots as $vendorDir) {
    $base = "$root/app/code/$vendorDir";
    // 1. Constructor arguments.
    foreach (rglob($base, '*.php') as $php) {
        if (preg_match('#/Test/|/registration\.php$#', $php) || in_array(moduleOf($php, $root), $disabled, true)) continue;
        $src = file_get_contents($php);
        if (!preg_match('/^namespace\s+([^;]+);/m', $src)) continue;
        if (!preg_match('/function\s+__construct\s*\((.*?)\)\s*[{:]/s', $src, $cm)) continue;
        // An abstract class is never instantiated directly; its children receive the arguments.
        if (preg_match('/^\s*abstract\s+class\s/m', $src)) continue;
        preg_match('/^namespace\s+([^;]+);/m', $src, $nsm);
        $selfClass = preg_match('/^\s*(?:final\s+|readonly\s+)*class\s+(\w+)/m', $src, $cn) ? trim($nsm[1]) . '\\' . $cn[1] : '';
        foreach (preg_split('/,(?![^(]*\))/', $cm[1]) as $param) {
            if (!preg_match('/^\s*(?:#\[[^\]]*\]\s*)?(?:(?:public|private|protected|readonly)\s+)*(\??)([\\\\\w|]+)\s+&?\s*(?:\.\.\.)?\$(\w+)\s*(=\s*(.*))?$/s', $param, $pm)) continue;
            $optional = $pm[1] === '?' || (isset($pm[5]) && preg_match('/^\s*null\s*$/i', $pm[5]))
                || isset($configuredArgs[$selfClass][$pm[3]]);
            foreach (explode('|', $pm[2]) as $type) {
                if (preg_match('/^(array|string|int|float|bool|mixed|callable|iterable|object|null|self|static|false|true)$/i', $type)) continue;
                $check(resolveName($type, $src), substr($php, strlen($root) + 1) . ' (constructor)', !$optional);
            }
        }
    }
    // 2. di.xml / events.xml references.
    foreach (array_merge(rglob($base, 'di.xml'), rglob($base, 'events.xml')) as $xf) {
        if (strpos($xf, '/Test/') !== false || in_array(moduleOf($xf, $root), $disabled, true)) continue;
        $x = @simplexml_load_file($xf);
        if (!$x) continue;
        $rel = substr($xf, strlen($root) + 1);
        foreach ($x->xpath('//type') as $n) $check((string)$n['name'], $rel, false);
        foreach ($x->xpath('//preference') as $n) {
            $check((string)$n['for'], $rel, false);
            $check((string)$n['type'], $rel, false);
        }
        foreach ($x->xpath('//virtualType') as $n) $check((string)$n['type'], $rel, false);
        foreach ($x->xpath('//observer[@instance]') as $n) {
            if ((string)$n['disabled'] !== 'true') $check((string)$n['instance'], $rel, false);
        }
        foreach ($x->xpath('//*[@xsi:type="object"]') as $n) $check((string)$n, $rel, false);

        // 3. Plugins: class exists, target exists, every interceptor method has a target method.
        foreach ($x->xpath('//type[plugin]') as $type) {
            $target = ltrim((string)$type['name'], '\\');
            foreach ($type->plugin as $pl) {
                if ((string)$pl['disabled'] === 'true' || (string)$pl['type'] === '') continue;
                $pcls = ltrim((string)$pl['type'], '\\');
                $pf = fileFor($loader, $pcls, $root);
                if (!$pf) {
                    $add('MISSING_CLASS', $pcls, "$rel (plugin on $target)");
                    continue;
                }
                $tm = methodsOf($loader, $root, $target);
                if ($tm === null) {
                    $add('PLUGIN_TARGET_MISSING', $target, "$rel ($pcls)");
                    continue;
                }
                if (in_array('*', $tm, true)) continue;
                $tf = fileFor($loader, $target, $root);
                $targetIsInterface = $tf && isInterface($tf, $target);
                preg_match_all('/public\s+function\s+(before|after|around)(\w+)\s*\(/', file_get_contents($pf), $mm, PREG_SET_ORDER);
                foreach ($mm as $p) {
                    if (in_array(strtolower($p[2]), $tm, true)) continue;
                    $add($targetIsInterface ? 'PLUGIN_METHOD_ON_IFACE' : 'PLUGIN_METHOD_NO_TARGET', "$target::" . lcfirst($p[2]), "$pcls::{$p[1]}{$p[2]}");
                }
            }
        }
    }
}

ksort($findings);
foreach (array_keys($findings) as $line) echo $line, "\n";
$blocking = count(array_filter($findings, fn ($k) => $k !== 'PLUGIN_METHOD_ON_IFACE'));
fwrite(fopen("php://stderr", "w"), sprintf(
    "magento2-di-scan: roots=%s package=%s findings=%d blocking=%d disabled-modules-skipped=%d\n",
    implode(',', $roots),
    $opts['package'] ?: '-',
    count($findings),
    $blocking,
    count($disabled)
));
exit($blocking > 0 ? 1 : 0);
