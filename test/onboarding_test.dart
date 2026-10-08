import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/services/holiday_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy completed never implicitly skips onboarding', () async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    expect(await OnboardingScreen.isCompleted(), false);
  });

  test('completed reads only the active account envelope', () async {
    final store = ProfileAccountStore.instance;
    await store.write(store.ticket, {ProfileAccountStore.completedKey: true});
    expect(await OnboardingScreen.isCompleted(), true);
  });

  test('holiday selection persists under the active owner, not global keys', () async {
    await HolidayService.initialize();
    await HolidayService.setCountry('TR');
    await HolidayService.setRegion('TR');
    expect(HolidayService.country, 'TR');
    expect(HolidayService.region, 'TR');
    final store = ProfileAccountStore.instance;
    final data = await store.read(store.ticket);
    expect(data[ProfileAccountStore.countryKey], 'TR');
    expect(data[ProfileAccountStore.regionKey], 'TR');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('holiday.country'), false);
    expect(prefs.containsKey('holiday.region'), false);
  });
}
