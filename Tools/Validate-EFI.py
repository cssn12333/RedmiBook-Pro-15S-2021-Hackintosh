import hashlib, pathlib, plistlib, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'EFI')
c=plistlib.loads((root/'OC/config.plist').read_bytes())
for section,folder,key in [('ACPI','ACPI','Path'),('UEFI','Drivers','Path')]:
    entries=c[section]['Add' if section=='ACPI' else 'Drivers']
    for x in entries:
        if x['Enabled'] and not (root/'OC'/folder/x[key]).is_file(): raise SystemExit('Missing '+str(x[key]))
enabled=[x for x in c['Kernel']['Add'] if x['Enabled']]
for x in enabled:
    p=root/'OC/Kexts'/x['BundlePath']
    plistlib.loads((p/x['PlistPath']).read_bytes())
    if x['ExecutablePath'] and not (p/x['ExecutablePath']).is_file(): raise SystemExit('Missing executable '+str(p))
names=[x['BundlePath'] for x in enabled]
if names.index('NootedRed.kext')>names.index('AppleALC.kext'): raise SystemExit('NootedRed must precede AppleALC')
if names.index('Lilu.kext')>names.index('AirportRTW.kext'): raise SystemExit('Lilu must precede AirportRTW')
binary=root/'OC/Kexts/AirportRTW.kext/Contents/MacOS/AirportRTW'
if any(x['Enabled'] and x.get('Base')=='_rtw88_force_wifi_only' for x in c['Kernel']['Patch']):
    if hashlib.sha256(binary.read_bytes()).hexdigest()!='38b1e03fe383327aad5399ed92f7a931048ae47f4c1d67a21867ecd5b70c7060':
        raise SystemExit('Wi-Fi binary changed; re-audit or disable version-specific coexistence patch')
g=c['PlatformInfo']['Generic']
if not g['SystemSerialNumber'] or not g['MLB'] or not any(g['ROM']): print('PUBLIC TEMPLATE: personalize SMBIOS before use.')
print('File paths, plists, key load order and Wi-Fi patch compatibility verified. Run matching ocvalidate for schema checks.')
