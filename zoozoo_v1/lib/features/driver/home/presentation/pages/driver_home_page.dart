import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../bloc/driver_bloc.dart';
import '../../data/driver_state.dart';
import '../widgets/incoming_order_sheet.dart';
import '../views/driver_offline_view.dart';
import '../views/driver_waiting_view.dart';
import '../views/driver_trip_view.dart';
import '../views/driver_completed_view.dart';

/// Driver home page with order management
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  // Access bloc via context, but we need a reference for the listener removal
  DriverBloc? _bloc;
  bool _isOrderSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bloc = context.read<DriverBloc>();
      _bloc?.addListener(_onStateChanged);
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  @override
  void dispose() {
    _bloc?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = context.read<DriverBloc>().state;

    // Show order sheet when new order arrives
    if (state.status == DriverStatus.hasOrder && !_isOrderSheetShowing) {
      _showIncomingOrderSheet();
    }

    setState(() {});
  }

  void _showIncomingOrderSheet() {
    final bloc = context.read<DriverBloc>();
    if (bloc.state.currentOrder == null) return;

    _isOrderSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => IncomingOrderSheet(
        order: bloc.state.currentOrder!,
        onAccept: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.acceptOrder();
          _showSnackBar('已接單！前往接客');
        },
        onReject: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.rejectOrder();
          _showSnackBar('已拒絕訂單');
        },
        onTimeout: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.orderTimeout();
          _showSnackBar('訂單已逾時');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for state changes to rebuild UI
    final driverBloc = context.watch<DriverBloc>();
    final state = driverBloc.state;

    // Show different content based on status
    if (state.status == DriverStatus.online ||
        state.status == DriverStatus.hasOrder) {
      return DriverWaitingView(state: state);
    }

    if (state.status.hasActiveTrip) {
      return DriverTripView(state: state);
    }

    if (state.status == DriverStatus.completed) {
      return DriverCompletedView(state: state);
    }

    // Default: offline screen
    return const DriverOfflineView();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
