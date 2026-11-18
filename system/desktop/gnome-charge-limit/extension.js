// The battery's charge limit in Quick Settings, as the bar's Power tab has
// it under mango: UPower's switch, and where it charges again and where it
// stops, kept by dotnix-charge-limit-set (system/hardware/laptop.nix)
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {Slider} from 'resource:///org/gnome/shell/ui/slider.js';

const UPOWER = 'org.freedesktop.UPower';
const DEVICE = 'org.freedesktop.UPower.Device';
const HELPER = ['/run/wrappers/bin/pkexec', '/run/current-system/sw/bin/dotnix-charge-limit-set'];
const ICON = 'battery-good-charging-symbolic';
// (after the last move, so a drag sets it once)
const COMMIT_DELAY_MS = 700;

// a slider over min..max in steps of 5
const LimitRow = GObject.registerClass({
    Signals: {'changed': {}},
}, class LimitRow extends PopupMenu.PopupBaseMenuItem {
    _init(text, min, max) {
        super._init({activate: false, style_class: 'dotnix-charge-limit-row'});
        this._min = min;
        this._max = max;

        const box = new St.BoxLayout({vertical: true, x_expand: true, style: 'spacing: 6px;'});
        const top = new St.BoxLayout({x_expand: true});
        top.add_child(new St.Label({text, x_expand: true}));
        this._valueLabel = new St.Label({style: 'font-weight: bold;'});
        top.add_child(this._valueLabel);
        box.add_child(top);

        this._slider = new Slider(0);
        this._slider.x_expand = true;
        this._slider.accessible_name = text;
        this._slider.connect('notify::value', () => {
            this._showValue();
            if (!this._setting)
                this.emit('changed');
        });
        box.add_child(this._slider);
        this.add_child(box);
    }

    get value() {
        const raw = this._min + this._slider.value * (this._max - this._min);
        return Math.min(this._max, Math.max(this._min, Math.round(raw / 5) * 5));
    }

    set value(percent) {
        this._setting = true;
        this._slider.value = (Math.min(this._max, Math.max(this._min, percent)) - this._min) / (this._max - this._min);
        this._setting = false;
        this._showValue();
    }

    _showValue() {
        this._valueLabel.text = `${this.value}%`;
    }
});

const ChargeLimitToggle = GObject.registerClass(
class ChargeLimitToggle extends QuickMenuToggle {
    _init() {
        super._init({
            title: 'Limite de carga',
            iconName: ICON,
            toggleMode: false,
            visible: false,
        });

        this.menu.setHeader(ICON, 'Limite de carga da bateria',
            'Preserva a bateria quando fica na tomada');

        this._start = new LimitRow('Carregar quando estiver abaixo de', 20, 95);
        this._end = new LimitRow('Parar de carregar em', 50, 100);
        this.menu.addMenuItem(this._start);
        this.menu.addMenuItem(this._end);
        this._start.connect('changed', () => this._edited(this._start));
        this._end.connect('changed', () => this._edited(this._end));

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addSettingsAction('Configurações de energia', 'gnome-power-panel.desktop');

        this.connect('clicked', () => this._setEnabled(!this.checked));

        this._cancellable = new Gio.Cancellable();
        this._findBattery();
    }

    _findBattery() {
        Gio.DBus.system.call(UPOWER, '/org/freedesktop/UPower', UPOWER, 'EnumerateDevices',
            null, new GLib.VariantType('(ao)'), Gio.DBusCallFlags.NONE, -1, this._cancellable,
            (bus, res) => {
                let paths;
                try {
                    [paths] = bus.call_finish(res).deepUnpack();
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`dotnix-charge-limit: ${e.message}`);
                    return;
                }
                const path = paths.find(p => /\/battery_BAT\d+$/.test(p));
                if (path)
                    this._watch(path);
            });
    }

    _watch(path) {
        Gio.DBusProxy.new_for_bus(Gio.BusType.SYSTEM, Gio.DBusProxyFlags.NONE, null,
            UPOWER, path, DEVICE, this._cancellable, (o, res) => {
                try {
                    this._proxy = Gio.DBusProxy.new_for_bus_finish(res);
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`dotnix-charge-limit: ${e.message}`);
                    return;
                }
                // (UPower restarts when the values change: the proxy follows it)
                this._proxy.connectObject(
                    'g-properties-changed', () => this._sync(),
                    'notify::g-name-owner', () => this._sync(), this);
                this._sync();
            });
    }

    _property(name, fallback) {
        return this._proxy?.get_cached_property(name)?.unpack() ?? fallback;
    }

    _sync() {
        this.visible = this._property('ChargeThresholdSupported', false);
        if (!this.visible)
            return;
        const enabled = this._property('ChargeThresholdEnabled', false);
        const start = this._property('ChargeStartThreshold', 75);
        const end = this._property('ChargeEndThreshold', 80);
        this.checked = enabled;
        this.subtitle = enabled ? `${start}% – ${end}%` : 'Desligado';
        // (not over a value being edited)
        if (!this._commitId) {
            this._start.value = start;
            this._end.value = end;
        }
    }

    _setEnabled(enabled) {
        this._proxy?.call('EnableChargeThreshold', new GLib.Variant('(b)', [enabled]),
            Gio.DBusCallFlags.NONE, -1, this._cancellable, (proxy, res) => {
                try {
                    proxy.call_finish(res);
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`dotnix-charge-limit: ${e.message}`);
                }
                this._sync();
            });
    }

    _edited(row) {
        // the start always below the end: the other one moves out of the way
        if (this._start.value >= this._end.value) {
            if (row === this._start)
                this._end.value = Math.min(100, this._start.value + 5);
            else
                this._start.value = Math.max(20, this._end.value - 5);
        }
        if (this._commitId)
            GLib.source_remove(this._commitId);
        this._commitId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, COMMIT_DELAY_MS, () => {
            this._commitId = 0;
            this._commit(this._start.value, this._end.value);
            return GLib.SOURCE_REMOVE;
        });
    }

    _commit(start, end) {
        try {
            const helper = Gio.Subprocess.new([...HELPER, `${start}`, `${end}`],
                Gio.SubprocessFlags.STDERR_PIPE);
            helper.wait_check_async(this._cancellable, (proc, res) => {
                try {
                    proc.wait_check_finish(res);
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`dotnix-charge-limit: ${e.message}`);
                }
                this._sync();
            });
        } catch (e) {
            console.warn(`dotnix-charge-limit: ${e.message}`);
        }
        this.subtitle = this.checked ? `${start}% – ${end}%` : 'Desligado';
    }

    destroy() {
        this._cancellable.cancel();
        if (this._commitId)
            GLib.source_remove(this._commitId);
        this._commitId = 0;
        this._proxy?.disconnectObject(this);
        super.destroy();
    }
});

const Indicator = GObject.registerClass(
class Indicator extends SystemIndicator {
    _init() {
        super._init();
        this.quickSettingsItems.push(new ChargeLimitToggle());
    }
});

export default class ChargeLimitExtension extends Extension {
    enable() {
        this._indicator = new Indicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.quickSettingsItems.forEach(item => item.destroy());
        this._indicator.destroy();
        this._indicator = null;
    }
}
