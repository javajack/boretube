import 'dart:io';

import 'package:boretube_mobile/discovery/device_identifier.dart';
import 'package:boretube_mobile/discovery/net.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('parses the real VU3 device-desc.xml', () {
    final xml = File('test/fixtures/vu3/device-desc.xml').readAsStringSync();
    final d = DeviceIdentifier.parse(xml)!;
    expect(d.friendlyName, 'Living Room TV');
    expect(d.manufacturer, 'Sony');
    expect(d.modelName, 'BRAVIA VU3');
    expect(d.udn, '4506a0af-4fcb-437e-993f-c16dad673aef');
  });

  test('rejects garbage and empty devices', () {
    expect(DeviceIdentifier.parse('not xml'), isNull);
    expect(DeviceIdentifier.parse('<root/>'), isNull);
    expect(DeviceIdentifier.parse('<root><device/></root>'), isNull);
  });

  test('UDN without uuid: prefix is kept', () {
    final d = DeviceIdentifier.parse(
      '<root><device><friendlyName>X</friendlyName>'
      '<UDN>ABC</UDN></device></root>',
    )!;
    expect(d.udn, 'abc');
    expect(d.manufacturer, '');
  });

  test('identify() fetches :8008/ssdp/device-desc.xml', () async {
    final net = FakeNet(get: {
      'http://10.0.0.5:8008/ssdp/device-desc.xml':
          NetResponse(200, deviceDesc()),
      'http://10.0.0.6:8008/ssdp/device-desc.xml': const NetResponse(404, ''),
    });
    final id = DeviceIdentifier(net: net);
    expect((await id.identify('10.0.0.5'))!.friendlyName, 'Living Room TV');
    expect(await id.identify('10.0.0.6'), isNull);
    expect(await id.identify('10.0.0.7'), isNull);
  });
}
