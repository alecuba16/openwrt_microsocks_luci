'use strict';
'require form';
'require view';
'require ui';
'require rpc';

var callRcInit = rpc.declare({
	object: 'rc',
	method: 'init',
	params: [ 'name', 'action' ]
});

return view.extend({
	handleSaveApply: function (ev, mode) {
		return this.handleSave(ev).then(() => {
			return ui.changes.apply(mode == '0');
		}).then(() => {
			return callRcInit('microsocks', 'restart').then((ret) => {
				if (ret)
					throw new Error(_('Restart failed'));
				return true;
			});
		});
	},

	render: function () {
		let m, s, o;

		m = new form.Map('microsocks', _('microsocks'),
			_('SOCKS5 proxy settings. Save & Apply commits UCI, applies configuration, then restarts microsocks.'));

		s = m.section(form.NamedSection, 'config', 'microsocks', _('Server'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.Value, 'listenip', _('Listen IP'),
			_('Address for the SOCKS listener (e.g. 127.0.0.1, ::, or 0.0.0.0).'));
		o.rmempty = true;
		o.placeholder = '::';

		o = s.option(form.Value, 'port', _('Listen port'));
		o.datatype = 'port';
		o.placeholder = '1080';

		o = s.option(form.Value, 'bindaddr', _('Outgoing bind address'),
			_('Optional source address for connections initiated by the proxy.'));
		o.rmempty = true;

		o = s.option(form.Value, 'user', _('Username'),
			_('Leave empty to disable authentication.'));
		o.rmempty = true;

		o = s.option(form.Value, 'password', _('Password'));
		o.password = true;
		o.rmempty = true;

		o = s.option(form.Flag, 'auth_once', _('Authenticate once'),
			_('After the first authentication, do not require auth for subsequent connections on the same connection (use with username/password).'));
		o.rmempty = false;

		o = s.option(form.Flag, 'internet_access', _('Allow WAN access'),
			_('If your init script supports it, opens the SOCKS port on the firewall for access from the internet.'));
		o.rmempty = false;

		return m.render();
	}
});
