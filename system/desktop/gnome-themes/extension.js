// dotnix's themes in Quick Settings, like the bar's theme picker under
// mango: the switch flips dark and light, the menu lists the themes with
// their colors. dotnix-gnome-theme applies one to the whole session (GTK,
// the shell, the taskbar, the menu, the wallpaper); its state is read back
// from ~/.local/state/gnome-theme.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const APPLY = '/run/current-system/sw/bin/dotnix-gnome-theme';
const ICON = 'preferences-desktop-appearance-symbolic';

function readState(name) {
    const path = GLib.build_filenamev([GLib.get_user_state_dir(), 'gnome-theme', name]);
    try {
        const [, bytes] = GLib.file_get_contents(path);
        return new TextDecoder().decode(bytes).trim();
    } catch {
        return null;
    }
}

// a row: the theme's colors as dots, its name, a check when it's on
const ThemeItem = GObject.registerClass(
class ThemeItem extends PopupMenu.PopupBaseMenuItem {
    _init(theme) {
        super._init({style_class: 'dotnix-theme-item'});
        this.theme = theme;
        this._dots = new St.BoxLayout({style: 'spacing: 4px;', y_align: Clutter.ActorAlign.CENTER});
        this.add_child(this._dots);
        this.add_child(new St.Label({text: theme.label, x_expand: true, y_align: Clutter.ActorAlign.CENTER}));
    }

    showMode(mode) {
        this._dots.destroy_all_children();
        const colors = this.theme.modes[mode] ?? Object.values(this.theme.modes)[0];
        for (const color of [colors.bg, colors.accent, colors.red, colors.green, colors.yellow]) {
            this._dots.add_child(new St.Widget({
                style: `width: 12px; height: 12px; border-radius: 6px; background-color: ${color}; border: 1px solid rgba(127, 127, 127, 0.4);`,
            }));
        }
    }
});

const ThemeToggle = GObject.registerClass(
class ThemeToggle extends QuickMenuToggle {
    _init(path) {
        super._init({title: 'Tema', iconName: ICON, toggleMode: false});
        this._themes = JSON.parse(new TextDecoder().decode(
            GLib.file_get_contents(GLib.build_filenamev([path, 'themes.json']))[1]));

        this.menu.setHeader(ICON, 'Tema', 'O sistema inteiro, de uma vez');
        const section = new PopupMenu.PopupMenuSection();
        this._items = this._themes.map(theme => {
            const item = new ThemeItem(theme);
            item.connect('activate', () => this._apply(theme.name, this._mode()));
            section.addMenuItem(item);
            return item;
        });
        const scroll = new St.ScrollView({
            style: 'max-height: 420px;',
            hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.AUTOMATIC,
            overlay_scrollbars: true,
        });
        this.menu.addMenuItem(section);
        section.actor.get_parent().remove_child(section.actor);
        scroll.set_child(section.actor);
        this.menu.box.add_child(scroll);

        // the switch: dark on, light off
        this.connect('clicked', () => this._apply(this._name(), this._mode() === 'dark' ? 'light' : 'dark'));
        this._cancellable = new Gio.Cancellable();
        this._sync();
    }

    _name() {
        return readState('name') ?? this._themes[0].name;
    }

    _mode() {
        return readState('mode') ?? 'dark';
    }

    _sync() {
        const name = this._name();
        const mode = this._mode();
        const theme = this._themes.find(t => t.name === name);
        this.checked = mode === 'dark';
        this.subtitle = `${theme?.label ?? name} · ${mode === 'dark' ? 'escuro' : 'claro'}`;
        for (const item of this._items) {
            item.showMode(mode);
            item.setOrnament(item.theme.name === name
                ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NONE);
        }
    }

    _apply(name, mode) {
        const theme = this._themes.find(t => t.name === name);
        // (a theme without that mode keeps the one it has)
        if (theme && !theme.modes[mode])
            mode = Object.keys(theme.modes)[0];
        try {
            const proc = Gio.Subprocess.new([APPLY, name, mode], Gio.SubprocessFlags.NONE);
            proc.wait_check_async(this._cancellable, (p, res) => {
                try {
                    p.wait_check_finish(res);
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`dotnix-themes: ${e.message}`);
                }
                this._sync();
            });
        } catch (e) {
            console.warn(`dotnix-themes: ${e.message}`);
        }
    }

    destroy() {
        this._cancellable.cancel();
        super.destroy();
    }
});

const Indicator = GObject.registerClass(
class Indicator extends SystemIndicator {
    _init(path) {
        super._init();
        this.quickSettingsItems.push(new ThemeToggle(path));
    }
});

export default class ThemesExtension extends Extension {
    enable() {
        this._indicator = new Indicator(this.path);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.quickSettingsItems.forEach(item => item.destroy());
        this._indicator.destroy();
        this._indicator = null;
    }
}
