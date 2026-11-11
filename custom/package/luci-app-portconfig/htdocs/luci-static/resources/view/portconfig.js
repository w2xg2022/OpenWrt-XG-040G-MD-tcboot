'use strict';
'require view';
'require uci';
'require rpc';
'require poll';
'require ui';

const PORTS = [
	{ dev: 'eth1', name: _('Port 1'), speed: '2.5G' },
	{ dev: 'lan2', name: _('Port 2'), speed: '1G' },
	{ dev: 'lan3', name: _('Port 3'), speed: '1G' },
	{ dev: 'lan4', name: _('Port 4'), speed: '1G' }
];

const callDeviceStatus = rpc.declare({
	object: 'network.device',
	method: 'status',
	params: [ 'name' ],
	expect: { '': {} }
});

function fmtSpeed(st) {
	if (!st || !st.carrier)
		return _('no link');

	const m = String(st.speed || '').match(/^(\d+)([FH])?/);
	if (!m)
		return _('Connected');

	const s = +m[1];
	const d = (m[2] == 'H') ? ' (H)' : '';

	if (s >= 1000)
		return '%s GbE%s'.format((s % 1000) ? (s / 1000).toFixed(1) : s / 1000, d);

	return '%d M%s'.format(s, d);
}

function roleColor(role) {
	return (role == 'wan') ? '#e8584f' : '#4caf50';
}

return view.extend({
	load() {
		return Promise.all([
			uci.load('portconfig'),
			Promise.all(PORTS.map(p => L.resolveDefault(callDeviceStatus(p.dev), {})))
		]);
	},

	updateStatus(states) {
		PORTS.forEach((p, i) => {
			const st = states[i] || {};
			const img = document.getElementById('pc-icon-' + p.dev);
			const txt = document.getElementById('pc-speed-' + p.dev);

			if (img)
				img.src = L.resource('icons/port_%s.svg'.format(st.carrier ? 'up' : 'down'));
			if (txt)
				txt.textContent = fmtSpeed(st);
		});
	},

	renderCard(p, role, st) {
		const sel = E('select', {
			'class': 'cbi-input-select',
			'id': 'pc-role-' + p.dev,
			'style': 'width:100%;margin-top:.5em',
			'change': ev => {
				document.getElementById('pc-card-' + p.dev).style.borderColor = roleColor(ev.target.value);
			}
		}, [
			E('option', { 'value': 'lan', 'selected': (role != 'wan') ? '' : null }, 'LAN'),
			E('option', { 'value': 'wan', 'selected': (role == 'wan') ? '' : null }, 'WAN')
		]);

		return E('div', {
			'id': 'pc-card-' + p.dev,
			'style': 'flex:1 1 0;min-width:7em;max-width:11em;padding:.75em .5em;text-align:center;' +
				'border:3px solid %s;border-radius:6px'.format(roleColor(role))
		}, [
			E('div', { 'style': 'font-weight:bold' }, p.name),
			E('div', { 'style': 'font-size:85%;opacity:.7' }, '%s · %s'.format(p.speed, p.dev)),
			E('img', {
				'id': 'pc-icon-' + p.dev,
				'src': L.resource('icons/port_%s.svg'.format(st.carrier ? 'up' : 'down')),
				'style': 'width:48px;height:48px;margin:.4em auto;display:block'
			}),
			E('div', { 'id': 'pc-speed-' + p.dev, 'style': 'font-size:85%' }, fmtSpeed(st)),
			sel
		]);
	},

	render(data) {
		const states = data[1];

		poll.add(() => Promise.all(PORTS.map(p => L.resolveDefault(callDeviceStatus(p.dev), {})))
			.then(s => this.updateStatus(s)), 5);

		return E([], [
			E('h2', {}, _('Port Assignment')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Choose whether each physical port belongs to LAN or WAN. ' +
				  'If more than one port is set to WAN they are bridged together (br-wan). ' +
				  'At least one port must stay LAN. ' +
				  'If the port you are connected to is moved to WAN, reconnect your computer to a LAN port.')),
			E('div', { 'class': 'cbi-section' }, [
				E('div', {
					'style': 'display:flex;flex-wrap:wrap;gap:.75em;justify-content:center;padding:1em 0'
				}, PORTS.map((p, i) => this.renderCard(p, uci.get('portconfig', 'main', p.dev) || 'lan', states[i] || {}))),
				E('div', { 'style': 'text-align:center;font-size:90%' }, [
					E('span', { 'style': 'color:%s;font-weight:bold'.format(roleColor('lan')) }, '■ LAN'),
					' ',
					E('span', { 'style': 'color:%s;font-weight:bold'.format(roleColor('wan')) }, '■ WAN')
				])
			])
		]);
	},

	handleSave(ev) {
		let lan = 0;
		const roles = {};

		PORTS.forEach(p => {
			const v = document.getElementById('pc-role-' + p.dev).value;
			roles[p.dev] = v;
			if (v != 'wan')
				lan++;
		});

		if (lan == 0) {
			ui.addNotification(null, E('p', _('At least one port must stay LAN')), 'danger');
			return Promise.reject(new Error('no lan port'));
		}

		PORTS.forEach(p => uci.set('portconfig', 'main', p.dev, roles[p.dev]));

		return uci.save();
	},

	handleReset: null
});
