import 'package:flutter/foundation.dart';

/// The vm can be in multiple states at a time, DataloadingState contains all the different states that the vm can be in
/// init() is an abstract method that should contain all the data that is needed to be loaded in the VM at start
/// reloadData() is another method that just internally calls the init() method
/// Note: we need to set the isDataLoadFutureComplete to true, everytime after the completion
/// of the tasks that we are doing in the init() method
abstract class BaseViewModel extends ChangeNotifier {
  DataloadingState dataloadingState = DataloadingState.loading;

  Future init();

  Future<void> reloadData() async {
    dataloadingState = DataloadingState.loading;
    notifyListeners();
    init();
  }
}

enum DataloadingState { loading, error, dataLoadComplete }
