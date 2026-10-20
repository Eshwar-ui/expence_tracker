import 'package:expence_tracker/services/upi_india_service.dart';
import 'package:expence_tracker/utils/upi_payment_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing native discovery requests an app update, not app installation',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await expectLater(
        UpiIndiaService.getInstalledUpiApps(),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'APP_UPDATE_REQUIRED')));
  });

  test('discovery errors do not turn into an empty installed app list',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.eshwar.expensetracker/upi_payment');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(
                code: 'DISCOVERY_FAILED',
                message: 'Could not load payment apps.'));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await expectLater(
        UpiIndiaService.getInstalledUpiApps(),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'DISCOVERY_FAILED')));
  });

  test('discovery includes installed apps outside the old plugin list',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.eshwar.expensetracker/upi_payment');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInstalledApps');
      return [
        {
          'packageName': 'com.example.upi',
          'appName': 'Another UPI App',
          'icon': Uint8List(0)
        }
      ];
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final apps = await UpiIndiaService.getInstalledUpiApps();
    expect(apps.single.upiApplication.androidPackageName, 'com.example.upi');
    expect(apps.single.upiApplication.appName, 'Another UPI App');
  });

  test('direct payment opens the chosen app without submitting a payment',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.eshwar.expensetracker/upi_payment');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await UpiIndiaService.openPaymentApp(
        ApplicationMeta.ios(UpiApplication.phonePe));
    expect(calls, hasLength(1));
    expect(calls.single.method, 'openApp');
    expect(calls.single.arguments,
        {'packageName': UpiApplication.phonePe.androidPackageName});
  });

  test('personal links do not invent merchant fields or a payment mode', () {
    final uri = Uri.parse(UPIPaymentHelper.buildUpiUri(
        upiId: 'person@upi',
        name: 'A + B',
        amount: 10.5,
        note: 'Tea & snacks'));
    expect(uri.queryParameters['pn'], 'A + B');
    expect(uri.queryParameters['tn'], 'Tea & snacks');
    expect(uri.queryParameters['am'], '10.50');
    expect(uri.queryParameters.containsKey('mode'), isFalse);
    expect(uri.queryParameters.containsKey('mc'), isFalse);
    expect(uri.queryParameters.containsKey('tr'), isFalse);
  });

  test('merchant QR metadata survives amount entry', () {
    final uri = Uri.parse(UPIPaymentHelper.updateUpiAmount(
        'upi://pay?pa=shop@upi&pn=Shop&mc=5812&orgid=123&url=https%3A%2F%2Fexample.com',
        25));
    expect(uri.queryParameters['mc'], '5812');
    expect(uri.queryParameters['orgid'], '123');
    expect(uri.queryParameters['url'], 'https://example.com');
  });

  test('signed QR is forwarded unchanged and edits are rejected', () {
    const qr = 'upi://pay?pa=shop@upi&am=25&tr=ORDER123&sign=a%2Bb%3D&tn=Order';
    expect(UPIPaymentHelper.updateUpiAmount(qr, 25, note: 'Order'), qr);
    expect(() => UPIPaymentHelper.updateUpiAmount(qr, 30), throwsArgumentError);
    expect(() => UPIPaymentHelper.updateUpiAmount(qr, 25, note: 'Other'),
        throwsArgumentError);
  });

  test('dynamic QR reference is preserved', () {
    final uri = Uri.parse(UPIPaymentHelper.updateUpiAmount(
        'upi://pay?pa=shop@upi&am=25&tr=ORDER123&tid=TERMINAL1', 25));
    expect(uri.queryParameters['tr'], 'ORDER123');
    expect(uri.queryParameters['tid'], 'TERMINAL1');
  });

  test('ambiguous payees and invalid amounts are rejected', () {
    for (final qr in [
      'upi://pay?pa=a@upi&pa=b@upi',
      'upi://pay?pa=a@upi&am=NaN',
      'upi://pay?pa=a@upi&am=Infinity',
      'upi://pay?pa=a@upi&am=0',
      'upi://pay?pa=a@upi&am=1.234',
      'upi://pay?pa=a@upi&cu=USD',
    ]) {
      expect(UPIPaymentHelper.validateUpiUri(Uri.parse(qr)), isFalse);
    }
  });

  test('unknown or contradictory response never becomes success', () {
    for (final raw in [
      '',
      'Status=unsuccessful',
      'Status=SUCCESS&responseCode=91'
    ]) {
      expect(() => UpiIndiaService.parseAndroidResponse(raw),
          throwsA(isA<PlatformException>()));
    }
    expect(
        UpiIndiaService.parseAndroidResponse('Status=SUCCESS&responseCode=00')
            .status,
        UpiTransactionStatus.success);
    expect(UpiIndiaService.parseAndroidResponse('Status=SUBMITTED').status,
        UpiTransactionStatus.submitted);
  });

  test('every selected app receives its own package and original QR details',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.eshwar.expensetracker/upi_payment');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'Status=SUCCESS&responseCode=00';
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    for (final app in [
      UpiApplication.phonePe,
      UpiApplication.paytm,
      UpiApplication.googlePay,
      UpiApplication(
          androidPackageName: 'com.flipkart.super.money',
          appName: 'super.money')
    ]) {
      await UpiIndiaService.payNow(
          amount: '25',
          app: ApplicationMeta.ios(app),
          receiverUpiAddress: 'person@upi',
          receiverName: 'Person',
          originalUpiUri: 'upi://pay?pa=person@upi&pn=Person&tr=ORIGINAL123');
      final args = calls.last.arguments as Map;
      expect(args['packageName'], app.androidPackageName);
      expect(Uri.parse(args['uri'] as String).queryParameters['tr'],
          'ORIGINAL123');
    }
  });
}
