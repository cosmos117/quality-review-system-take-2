import 'package:get/get.dart';

class AdminDashboardUIController extends GetxController {
  final RxString searchQuery = ''.obs;
  final RxString sortKey = 'started'.obs;
  final RxBool ascending = false.obs; // newest first when false for date
  final RxInt hoverIndex = (-1).obs;
  final RxSet<String> selectedStatuses = <String>{}.obs;

  void setSearch(String v) => searchQuery.value = v;
  void toggleSort(String key) {
    if (sortKey.value == key) {
      ascending.value = !ascending.value;
    } else {
      sortKey.value = key;
      ascending.value = true;
    }
  }

  void setHover(int index) => hoverIndex.value = index;
  void clearHover() => hoverIndex.value = -1;

  void toggleStatus(String status) {
    if (selectedStatuses.contains(status)) {
      selectedStatuses.remove(status);
    } else {
      selectedStatuses.add(status);
    }
  }

  void clearFilters() => selectedStatuses.clear();
}
