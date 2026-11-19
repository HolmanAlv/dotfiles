#!/usr/bin/env python3
"""Writes the global theme packages to ~/.local/share/plasma/look-and-feel.

  build-theme.py capture [dump]  org.holman.tokyored and TokyoRed.colors, from the desktop as it is now
                                 (dump: a saved dumpCurrentLayoutJS to use instead of the live layout)
  build-theme.py neonninja       org.holman.neonninja, with the live desktop and this file's panels
  build-theme.py zafiro-extra D  icons/zafiro-extra.tar.zst, from D: the Dark folder of zayronxio/Zafiro-icons

The live layout holds the names of the files on the user's desktop, so the packages are
generated on the machine and never stored in the repo.
"""
import colorsys, json, os, re, shutil, subprocess, sys

HOME = os.path.expanduser('~')
REPO = os.path.dirname(os.path.realpath(__file__))
LNF = f'{HOME}/.local/share/plasma/look-and-feel'
SCHEMES = f'{HOME}/.local/share/color-schemes'
CAPTURED_GRID_UNIT = 16  # px, with the fonts org.holman.tokyored keeps
BAR = 48  # px: the Dell's 26 px on 768 of height (3.4 %), on 1440
ICONS = 'Zafiro-Red'
APP_ICONS = {
    'com.rtosta.zapzap': 'whatsapp',
    'appimagekit_0761d8deb669414dd30de877918d42d5_todoist': 'todoist',
    'net.lutris.Lutris': 'lutris',
    'org.gnome.Meld': 'meld',
    'java27-openjdk': 'java',
    'btop': 'utilities-system-monitor',  # the icon Zafiro gives htop
    'haruna': 'com.georgefb.haruna.desktop',
    'org.prismlauncher.PrismLauncher': 'minecraft',
    'gh-desktop-plus': 'github-desktop',  # Desktop Plus is a GitHub Desktop fork
    'com.heroicgameslauncher.hgl': 'epic-games',
}
# Directories of the upstream Zafiro that add to the repo's copy, as upstream defines them. Not its panel: the tray stays Papirus.
ZAFIRO_EXTRA = {
    'apps/scalable': 'Context=Applications\nSize=48\nMinSize=16\nMaxSize=512\nType=Scalable',
    'mimetypes/48': 'Context=MimeTypes\nSize=48\nMinSize=8\nMaxSize=512\nType=Scalable',
    'devices/48': 'Context=Devices\nSize=48\nMinSize=8\nMaxSize=1024\nType=Scalable',
    'devices/22': 'Context=Devices\nSize=22\nType=Scalable',
    'categories/22-Dark': 'Context=Categories\nSize=22\nMinSize=8\nMaxSize=256\nType=Scalable',
    'emblems/16': 'Context=Emblems\nSize=16\nMinSize=8\nMaxSize=512\nType=Scalable',
    'places/16-A': 'Context=Places\nSize=16\nMinSize=8\nMaxSize=32\nType=Scalable',
    'actions/16-Dark': 'Context=Actions\nSize=16\nType=Fixed',
    'actions/22-Dark': 'Context=Actions\nSize=22\nType=Fixed',
}
# Breeze's one-color directories: what no Zafiro has, without the colored icons that clash with it.
# Except applets from 48 up and emotes, which are colored but only show in the widget list and among faces.
BREEZE_LINES = {'actions': (12, 16, 22, 24, 32), 'status': (16, 22, 24), 'applets': (16, 22, 48, 256), 'devices': (16, 22),
                'emblems': (8, 16, 22), 'animations': (16, 22), 'categories': (22,), 'preferences': (22,), 'emotes': (22,)}
FONT = 'M PLUS 1 Neon,{},-1,5,{},0,0,0,0,0,0,0,0,0,0,1'  # make-fonts.py

# (file, group, key): what a global theme does not apply by itself. A value of None removes the key.
SETTINGS = [
    ('kdeglobals', 'General', 'font'), ('kdeglobals', 'General', 'fixed'), ('kdeglobals', 'General', 'menuFont'),
    ('kdeglobals', 'General', 'smallestReadableFont'), ('kdeglobals', 'General', 'toolBarFont'),
    ('kdeglobals', 'General', 'AccentColor'), ('kdeglobals', 'General', 'LastUsedCustomAccentColor'),
    ('kdeglobals', 'General', 'TerminalApplication'), ('kdeglobals', 'General', 'TerminalService'),
    ('kdeglobals', 'WM', 'activeFont'), ('kdeglobals', 'KDE', 'AnimationDurationFactor'),
    ('kwinrc', 'Plugins', 'magiclampEnabled'), ('kwinrc', 'Plugins', 'squashEnabled'),
    ('kwinrc', 'TabBox', 'LayoutName'), ('kwinrc', 'Effect-scale', 'Duration'),
    ('kwinrc', 'Effect-scale', 'InScale'), ('kwinrc', 'Effect-scale', 'OutScale'),
    ('krunnerrc', 'General', 'RetainPriorSearch'), ('krunnerrc', 'Plugins', 'krunner_appstreamEnabled'),
    ('krunnerrc', 'Plugins', 'krunner_dictionaryEnabled'), ('krunnerrc', 'Plugins', 'krunner_spellcheckEnabled'),
    ('krunnerrc', 'Plugins', 'krunner_katesessionsEnabled'), ('krunnerrc', 'Plugins', 'krunner_konsoleprofilesEnabled'),
    ('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnLeft'), ('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnRight'),
    ('kwinrc', 'Plugins', 'kwin4_effect_geometry_changeEnabled'),
]


def out(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout


def parse_layout(dump):
    return json.loads(dump[dump.index('var layout = ') + 13:dump.rindex(';\n\nplasma.loadSerializedLayout')])


def live_layout():
    return parse_layout(out('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.dumpCurrentLayoutJS'))


def read(file, group, key):
    return out('kreadconfig6', '--file', file, '--group', group, '--key', key).rstrip('\n')


def layout_script(layout, settings):
    return f'''var plasma = getApiVersion(1);
var layout = {json.dumps(layout, indent=4)};
plasma.loadSerializedLayout(layout);

// loadSerializedLayout leaves the panels at their default size and behavior.
// In px: the grid unit follows the theme's font, so a stored size in units would change with it.
panels().forEach(function (p) {{
    layout.panels.forEach(function (s) {{
        if (s.location !== p.location) return;
        p.height = s.px;
        p.hiding = s.hiding;
        p.floating = s.floating;
        p.opacity = s.opacity;
        p.lengthMode = s.lengthMode;
    }});
}});

{json.dumps(settings)}.forEach(function (s) {{
    var path = s[1].split("/");
    var c = ConfigFile(s[0], path[0]);
    if (path[1]) c = ConfigFile(c, path[1]);
    if (s[3] === null) c.deleteEntry(s[2]); else c.writeEntry(s[2], s[3]);
}});
'''


def write_package(pid, name, description, defaults, layout, settings, wallpaper):
    root = f'{LNF}/{pid}'
    for d in ('contents/layouts', 'contents/previews'):
        os.makedirs(f'{root}/{d}', exist_ok=True)
    meta = {'KPackageStructure': 'Plasma/LookAndFeel',
            'KPlugin': {'Authors': [{'Name': 'Holman Alvarado'}], 'Description': description,
                        'Id': pid, 'License': 'MIT', 'Name': name, 'Version': '1'}}
    with open(f'{root}/metadata.json', 'w') as f:
        json.dump(meta, f, indent=2)
    with open(f'{root}/contents/defaults', 'w') as f:
        f.write(defaults)
    with open(f'{root}/contents/layouts/org.kde.plasma.desktop-layout.js', 'w') as f:
        f.write(layout_script(layout, settings))
    if wallpaper:
        for size, file in (('640x360', 'preview.png'), ('1920x1080', 'fullscreenpreview.jpg')):
            subprocess.run(['magick', wallpaper, '-resize', f'{size}^', '-gravity', 'center', '-extent', size,
                            f'{root}/contents/previews/{file}'], check=True)


def wallpaper_of(desktop):
    return desktop['config'].get('/Wallpaper/org.kde.image/General', {}).get('Image', '').removeprefix('file://')


def scheme_from_kdeglobals(name, title):
    # What is applied now, accent included. The .colors file alone has no accent: it was set on top of it.
    with open(f'{HOME}/.config/kdeglobals') as f:
        sections = re.split(r'(?m)^(?=\[)', f.read())
    keep = [s for s in sections if s.startswith(('[ColorEffects:', '[Colors:'))]
    wm = next((s for s in sections if s.startswith('[WM]')), '')
    wm = ''.join(l for l in wm.splitlines(True) if not l.startswith('activeFont'))
    head = f'[General]\nColorScheme={name}\nName={title}\n\n[KDE]\ncontrast={read("kdeglobals", "KDE", "contrast")}\n\n'
    os.makedirs(SCHEMES, exist_ok=True)
    with open(f'{SCHEMES}/{name}.colors', 'w') as f:
        f.write(head + ''.join(keep) + wm)


def header_inactive(scheme):
    # Applying a scheme only writes this group when a separate accent is set, so it would keep the last theme's colors
    with open(f'{SCHEMES}/{scheme}.colors') as f:
        body = re.search(r'(?ms)^\[Colors:Header\]\[Inactive\]\n(.*?)(?=^\[|\Z)', f.read()).group(1)
    return [['kdeglobals', 'Colors:Header/Inactive', *line.split('=', 1)] for line in body.split()]


def capture(dump_file=None):
    layout = parse_layout(open(dump_file).read()) if dump_file else live_layout()
    for panel in layout['panels']:
        panel['px'] = round(panel['height'] * CAPTURED_GRID_UNIT)
    if not os.path.exists(f'{SCHEMES}/TokyoRed.colors'):
        scheme_from_kdeglobals('TokyoRed', 'Tokyo Red')
    defaults = f'''[kdeglobals][KDE]
widgetStyle={read('kdeglobals', 'KDE', 'widgetStyle')}

[kdeglobals][General]
ColorScheme=TokyoRed

[kdeglobals][Icons]
Theme={read('kdeglobals', 'Icons', 'Theme')}

[kcminputrc][Mouse]
cursorTheme={read('kcminputrc', 'Mouse', 'cursorTheme')}

[plasmarc][Theme]
name={read('plasmarc', 'Theme', 'name')}

[kwinrc][org.kde.kdecoration2]
library={read('kwinrc', 'org.kde.kdecoration2', 'library')}
theme={read('kwinrc', 'org.kde.kdecoration2', 'theme')}

[kwinrc][WindowSwitcher]
LayoutName={read('kwinrc', 'TabBox', 'LayoutName')}

[ksplashrc][KSplash]
Theme={read('ksplashrc', 'KSplash', 'Theme') or 'Nordic'}
'''
    # The accent lives in the scheme: an AccentColor key would tint it again when a theme is applied
    settings = [[*s, None if 'AccentColor' in s[2] else read(*s) or None] for s in SETTINGS] + header_inactive('TokyoRed')
    write_package('org.holman.tokyored', 'Tokyo Red', 'The desktop as it was before Neon Ninja',
                  defaults, layout, settings, wallpaper_of(layout['desktops'][0]))


def stats(title, sensor, color):
    return {'plugin': 'org.kde.plasma.systemmonitor', 'config': {
        '/': {'CurrentPreset': 'org.kde.plasma.systemmonitor'},
        '/Appearance': {'chartFace': 'org.holman.neonbars', 'title': title, 'showTitle': 'false', 'updateRateLimit': '2000'},
        '/SensorColors': {sensor: color},
        '/Sensors': {'highPrioritySensorIds': f'[\"{sensor}\"]'}}}


def zafiro_extra(upstream):
    have = set()
    for _, _, files in os.walk(f'{HOME}/.local/share/icons/Zafiro', followlinks=True):
        have |= {f.rsplit('.', 1)[0] for f in files}
    # KDE shortens a missing name at its dashes within each theme before trying the next, and Zafiro-Red comes first:
    # an `edit` in it would replace Zafiro's edit-find
    prefixes = {h[:i] for h in have for i, c in enumerate(h) if c == '-'}
    new = sorted(f'{d}/{f}' for d in ZAFIRO_EXTRA for f in os.listdir(f'{upstream}/{d}')
                 if f.rsplit('.', 1)[0] not in have and os.path.exists(f'{upstream}/{d}/{f}')
                 and re.sub(r'(-x-generic|-symbolic)$', '', f.rsplit('.', 1)[0]) not in prefixes)
    os.makedirs(f'{REPO}/icons', exist_ok=True)
    subprocess.run(['tar', '-C', upstream, '-h', '--sort=name', '--owner=0', '--group=0', '--mtime=@0', '--zstd',
                    '-cf', f'{REPO}/icons/zafiro-extra.tar.zst', '-T', '-'], input='\n'.join(new), text=True, check=True)


def zafiro_red():
    # Zafiro with every folder in the accent's hue, Papirus' monochrome tray and the upstream icons the repo's copy lacks.
    # What is not here falls back to Zafiro, and what Zafiro lacks (half of the names Plasma asks for, which would otherwise
    # be blank) to a theme with Breeze's one-color icons. Mime types then fall back to Zafiro's generic ones.
    source = f'{HOME}/.local/share/icons/Zafiro/places/48'
    root = f'{HOME}/.local/share/icons/{ICONS}'
    shutil.rmtree(root, ignore_errors=True)
    os.makedirs(f'{root}/places/48')
    os.makedirs(f'{root}/panel')

    def red(match):
        code = match.group(0)
        hue, light, saturation = colorsys.rgb_to_hls(*(int(code[i:i + 2], 16) / 255 for i in (1, 3, 5)))
        if saturation < 0.08 and not 0.6 < light < 0.9:  # white glyphs and black shadows stay; the plain folder's gray does not
            return code
        return '#%02x%02x%02x' % tuple(round(c * 255) for c in colorsys.hls_to_rgb(351 / 360, max(0.34, min(light, 0.66)), 0.72))

    recolored = {n for n in os.listdir(source) if re.match(r'(folder|user-(home|desktop|bookmarks))', n)
                 and n.endswith('.svg') and not os.path.islink(f'{source}/{n}')}
    for name in os.listdir(source):
        target = os.path.basename(os.path.realpath(f'{source}/{name}'))
        if name in recolored:
            with open(f'{source}/{name}') as f, open(f'{root}/places/48/{name}', 'w') as o:
                o.write(re.sub(r'#[0-9a-fA-F]{6}\b', red, f.read()))
        elif target in recolored:
            os.symlink(target, f'{root}/places/48/{name}')
    sizes = (16, 22, 24)
    for size in sizes:
        os.symlink(f'/usr/share/icons/Papirus-Dark/{size}x{size}/panel', f'{root}/panel/{size}')
    # Papirus has no clipboard icon under the name Plasma asks for, so it would get Zafiro's in color
    os.makedirs(f'{root}/status/22')
    os.symlink('/usr/share/icons/breeze-dark/status/22/klipper-symbolic.svg', f'{root}/status/22/klipper-symbolic.svg')
    subprocess.run(['tar', '-C', root, '--zstd', '-xf', f'{REPO}/icons/zafiro-extra.tar.zst'], check=True)
    # Files of no known type, in Zafiro itself: in Zafiro-Red, by the rule above, it would replace every application-* icon.
    # Without it they get Adwaita's 16 px image, blurred.
    for name in ('application-x-generic', 'unknown'):
        shutil.copy(f'{REPO}/icons/application-x-generic.svg', f'{HOME}/.local/share/icons/Zafiro/mimetypes/48/{name}.svg')
    # Office documents: Zafiro's muted fills read as gray on a dark background, so each takes its program's color
    office = {'#94add1': '#2b7cd3', '#7378b1': '#2b7cd3', '#a7ac93': '#21a366', '#ce8e64': '#d35230',
              '#659b92': '#a4373a'}
    for d in (f'{HOME}/.local/share/icons/Zafiro/mimetypes/48', f'{root}/mimetypes/48'):
        for name in os.listdir(d):
            if name.endswith('.svg') and not os.path.islink(f'{d}/{name}'):
                with open(f'{d}/{name}', errors='replace') as f:
                    svg = f.read()
                new = re.sub(r'#[0-9a-fA-F]{6}\b', lambda m: office.get(m.group(0).lower(), m.group(0)), svg)
                if new != svg:
                    with open(f'{d}/{name}', 'w') as o:
                        o.write(new)
    # Draw shares its drawing with SVG images, which keep their color: it gets its own copy, here in the first theme
    odf = 'application-vnd.oasis.opendocument'
    with open(f'{HOME}/.local/share/icons/Zafiro/mimetypes/48/{odf}.graphics.svg') as f, open(f'{root}/mimetypes/48/{odf}.graphics.svg', 'w') as o:
        o.write(f.read().replace('#6f918a', '#e8a33d'))
    os.symlink(f'{odf}.database.svg', f'{root}/mimetypes/48/{odf}.base.svg')
    # Apps Zafiro has an icon for under another name. Copies, since the source may be in either theme.
    # ponytail: exact names, so Java's version and the AppImage's hash need updating if they change
    for name, source in APP_ICONS.items():
        found = f'{root}/apps/scalable/{source}.svg'
        if not os.path.exists(found):
            found = f'{HOME}/.local/share/icons/Zafiro/apps/scalable/{source}.svg'
        shutil.copy(found, f'{root}/apps/scalable/{name}.svg')
    lines = f'{root}-Lines'
    shutil.rmtree(lines, ignore_errors=True)
    breeze = [f'{c}/{s}' for c, group in BREEZE_LINES.items() for s in group]
    for d in breeze:
        os.makedirs(os.path.dirname(f'{lines}/{d}'), exist_ok=True)
        os.symlink(f'/usr/share/icons/breeze-dark/{d}', f'{lines}/{d}')
    with open(f'{lines}/index.theme', 'w') as f:
        f.write(f'[Icon Theme]\nName={ICONS}-Lines\nComment=Breeze one-color icons, the last fallback of {ICONS}\nHidden=true\n'
                'Directories=' + ','.join(breeze) + '\n\n'
                + '\n'.join(f'[{d}]\nSize={d.split("/")[1]}\nType=Fixed\n' for d in breeze))
    with open(f'{root}/index.theme', 'w') as f:
        # The panel comes before the additions, so that a name in both stays monochrome in the tray
        f.write(f'[Icon Theme]\nName={ICONS}\nComment=Zafiro with red folders\nInherits=Zafiro,{ICONS}-Lines\n'
                'Directories=places/48,status/22,' + ','.join([f'panel/{s}' for s in sizes] + list(ZAFIRO_EXTRA)) + '\n\n'
                + ''.join(f'[{d}]\n{spec}\n\n' for d, spec in ZAFIRO_EXTRA.items()) +
                '[status/22]\nContext=Status\nSize=22\nType=Fixed\n\n'
                # From 32 px up: the Zafiro below keeps its own smaller line icons for the places panel
                '[places/48]\nContext=Places\nSize=48\nMinSize=32\nMaxSize=512\nType=Scalable\n\n'
                + '\n'.join(f'[panel/{s}]\nContext=Status\nSize={s}\nType=Fixed\n' for s in sizes))


def neonninja():
    live = live_layout()
    dock = next(p for p in live['panels'] if any(a['plugin'] == 'org.kde.plasma.quicklaunch' for a in p['applets']))
    shelly = next(a for p in live['panels'] for a in p['applets'] if a['plugin'] == 'org.kde.plasma.icon')
    dock.update(hiding='dodgewindows', location='left', floating=True, opacity='translucent', lengthMode='fit', px=47)
    bar = {'alignment': 'center', 'floating': False, 'floatingApplets': False, 'height': 3, 'hiding': 'dodgewindows',
           'lengthMode': 'fill', 'location': 'bottom', 'maximumLength': 160, 'minimumLength': 160, 'offset': 0,
           'opacity': 'opaque', 'px': BAR,
           'config': {'/': {'formfactor': '2', 'immutability': '1', 'lastScreen': '0', 'wallpaperplugin': 'org.kde.image'}},
           'applets': [
               {'plugin': 'org.kde.plasma.kickoff', 'config': {'/General': {'icon': 'neonninjastart', 'favoritesPortedToKAstats': 'true'}}},
               shelly,
               {'plugin': 'org.holman.spacer', 'config': {}},
               {'plugin': 'org.kde.plasma.icontasks', 'config': {'/General': {'fill': 'false', 'launchers': ''}}},
               {'plugin': 'org.holman.spacer', 'config': {}},
               {'plugin': 'org.kde.plasma.systemtray', 'config': {}},
               # Vendor colors, never themed: blue Intel, green NVIDIA, as on the desktop these replace
               stats('CPU', 'cpu/all/usage', '136,192,208'),
               stats('GPU', 'gpu/gpu0/usage', '163,190,140'),
               stats('RAM', 'memory/physical/usedPercent', '180,142,173'),
               {'plugin': 'org.holman.neonclock', 'config': {}},
               {'plugin': 'org.kde.plasma.icon', 'config': {'/': {'url': f'file://{HOME}/.local/share/applications/neon-ninja-leave.desktop'}}},
               {'plugin': 'org.kde.plasma.pager', 'config': {}},
           ]}
    layout = {'desktops': live['desktops'], 'panels': [bar, dock], 'serializationFormatVersion': '1'}
    zafiro_red()
    defaults = f'''[kdeglobals][KDE]
widgetStyle=Darkly

[kdeglobals][General]
ColorScheme=NeonNinja

[kdeglobals][Icons]
Theme={ICONS}

[kcminputrc][Mouse]
cursorTheme={read('kcminputrc', 'Mouse', 'cursorTheme')}

[plasmarc][Theme]
name=Square

[kwinrc][org.kde.kdecoration2]
library=org.kde.darkly
theme=Darkly

[kwinrc][WindowSwitcher]
LayoutName=thumbnail_grid

[ksplashrc][KSplash]
Theme=org.holman.neonninja
'''
    values = {
        ('kdeglobals', 'General', 'font'): FONT.format(10, 400),
        ('kdeglobals', 'General', 'menuFont'): FONT.format(10, 400),
        ('kdeglobals', 'General', 'toolBarFont'): FONT.format(10, 400),
        ('kdeglobals', 'General', 'smallestReadableFont'): FONT.format(8, 400),
        ('kdeglobals', 'General', 'fixed'): 'Moralerspace Neon,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1',
        ('kdeglobals', 'WM', 'activeFont'): FONT.format(9, 700),
        ('kdeglobals', 'General', 'TerminalApplication'): f'kitty --config {HOME}/.config/kitty/neon-ninja.conf',
        ('kdeglobals', 'KDE', 'AnimationDurationFactor'): read('kdeglobals', 'KDE', 'AnimationDurationFactor') or None,
        ('kwinrc', 'Plugins', 'magiclampEnabled'): 'false',
        ('kwinrc', 'Plugins', 'squashEnabled'): 'false',
        ('kwinrc', 'TabBox', 'LayoutName'): 'thumbnail_grid',
        ('kwinrc', 'Plugins', 'kwin4_effect_geometry_changeEnabled'): 'true',
        # The repo's picom: open and close at 0.92 in 150 ms
        ('kwinrc', 'Effect-scale', 'Duration'): '150',
        ('kwinrc', 'Effect-scale', 'InScale'): '0.92',
        ('kwinrc', 'Effect-scale', 'OutScale'): '0.92',
        ('krunnerrc', 'General', 'RetainPriorSearch'): 'false',
        ('krunnerrc', 'Plugins', 'krunner_appstreamEnabled'): 'false',
        ('krunnerrc', 'Plugins', 'krunner_dictionaryEnabled'): 'false',
        ('krunnerrc', 'Plugins', 'krunner_spellcheckEnabled'): 'false',
        ('krunnerrc', 'Plugins', 'krunner_katesessionsEnabled'): 'false',
        ('krunnerrc', 'Plugins', 'krunner_konsoleprofilesEnabled'): 'false',
        ('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnLeft'): '',
        ('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnRight'): 'IAX',
    }
    settings = [[*s, values.get(s)] for s in SETTINGS] + header_inactive('NeonNinja')
    write_package('org.holman.neonninja', 'Neon Ninja', 'Black and neon red, straight corners, Japanese type',
                  defaults, layout, settings, wallpaper_of(live['desktops'][0]))
    splash = f'{LNF}/org.holman.neonninja/contents/splash'
    shutil.copytree(f'{REPO}/splash', splash, dirs_exist_ok=True)
    os.makedirs(f'{splash}/images', exist_ok=True)
    shutil.copy(f'{REPO}/home/.config/fastfetch/ninja.png', f'{splash}/images/logo.png')
    subprocess.run(['magick', wallpaper_of(live['desktops'][0]), '-resize', '1920x1080^', '-gravity', 'center', '-extent', '1920x1080',
                    '-modulate', '35', '-quality', '85', f'{splash}/images/background.jpg'], check=True)


if __name__ == '__main__':
    if sys.argv[1:2] == ['capture']:
        capture(*sys.argv[2:3])
    elif sys.argv[1:] == ['neonninja']:
        neonninja()
    elif sys.argv[1:2] == ['zafiro-extra'] and len(sys.argv) == 3:
        zafiro_extra(sys.argv[2])
    else:
        sys.exit(__doc__)
