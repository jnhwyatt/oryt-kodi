# -*- coding: utf-8 -*-
import json
import xbmc, xbmcvfs
from caches.settings_cache import get_setting, set_setting

account_file = 'special://home/addons/plugin.video.oryttv/resources/data/oryt_account.json'
seed_keys = ('rd.token', 'rd.refresh', 'rd.client_id', 'rd.secret', 'rd.account_id')
empty_values = ('', 'empty_setting')

def seed_account():
	try:
		account_path = xbmcvfs.translatePath(account_file)
		if not xbmcvfs.exists(account_path): return
		with open(account_path, 'r') as f: account_data = json.load(f)
	except: return
	if not isinstance(account_data, dict): return
	seeded = []
	for setting_id in seed_keys:
		value = account_data.get(setting_id, '')
		if not value: continue
		if not get_setting('fenlight.%s' % setting_id) in empty_values: continue
		set_setting(setting_id, value)
		seeded.append(setting_id)
	if seeded: xbmc.log('###Oryt###: Account Seed - Seeded: %s' % ', '.join(seeded), 1)
	else: xbmc.log('###Oryt###: Account Seed - Nothing to Seed', 1)
	if not get_setting('fenlight.rd.token') in empty_values and get_setting('fenlight.rd.enabled') != 'true':
		set_setting('rd.enabled', 'true')
		xbmc.log('###Oryt###: Account Seed - Real-Debrid Enabled', 1)
