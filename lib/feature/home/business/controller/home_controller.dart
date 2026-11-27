import 'package:get/get.dart';
import '../../../auth/business/controller/auth_controller.dart';
import '../../../measure/data/models/measurement_model.dart';

class HomeController extends GetxController {
  final _authController = Get.find<AuthController>();
  final _measurementService = MeasurementService();

  final Rx<MeasurementModel?> latestMeasurement = Rx<MeasurementModel?>(null);
  final RxBool isLoadingLatest = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLatestMeasurement();
  }

  Future<void> fetchLatestMeasurement() async {
    isLoadingLatest.value = true;
    try {
      final latest = await _measurementService.getLatestMeasurement();
      latestMeasurement.value = latest;
      print('✅ تم تحميل آخر قياس: ${latest?.value}');
    } catch (e) {
      print('❌ خطأ في تحميل آخر قياس: $e');
    } finally {
      isLoadingLatest.value = false;
    }
  }

  // تحديث آخر قياس (مفيد عندما يضيف المستخدم قياس جديد)
  Future<void> refreshLatestMeasurement() async {
    await fetchLatestMeasurement();
  }

  void navigateTo(String route) => Get.toNamed(route);
  void logout() => _authController.logout();

  String get userName =>
      _authController.currentUser.value?.fullName ?? 'مستخدم عزيز';
  String? get userImageUrl =>
      _authController.currentUser.value?.profileImageUrl;
}
