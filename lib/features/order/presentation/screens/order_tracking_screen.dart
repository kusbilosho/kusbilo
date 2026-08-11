import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/order.dart';

/// Live tracking for a single order — status timeline + ETA countdown up
/// top (like any e-commerce app's "order placed / confirmed / out for
/// delivery / delivered" strip), an order summary, and a live map of the
/// seller's position once they're actually on the way. Built on
/// flutter_map + OpenStreetMap tiles: no Google Maps API key needed.
class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.trackOrderTitle, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const OrderTrackingSkeleton();
          }
          final raw = snapshot.data!.data();
          if (raw == null) {
            return Center(child: Text(strings.orderNotFound));
          }

          final order = Order.fromMap(snapshot.data!.id, raw);
          final liveLat = (raw['liveLat'] as num?)?.toDouble();
          final liveLng = (raw['liveLng'] as num?)?.toDouble();
          final hasLivePoint = liveLat != null && liveLng != null && order.status == OrderStatus.outForDelivery;
          final hasDeliveryPoint = order.deliveryLat != null && order.deliveryLng != null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(color: Colors.white, child: _StatusTimeline(order: order, strings: strings)),
                if (order.status != OrderStatus.cancelled && order.status != OrderStatus.delivered)
                  _EtaCountdown(order: order, strings: strings),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _OrderSummaryCard(order: order, strings: strings),
                ),
                const SizedBox(height: 16),
                if (order.status == OrderStatus.outForDelivery && hasDeliveryPoint)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 320,
                        child: _TrackingMap(
                          deliveryPoint: latlng.LatLng(order.deliveryLat!, order.deliveryLng!),
                          livePoint: hasLivePoint ? latlng.LatLng(liveLat, liveLng) : null,
                        ),
                      ),
                    ),
                  )
                else if (order.status != OrderStatus.delivered &&
                    order.status != OrderStatus.cancelled &&
                    hasDeliveryPoint)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _WaitingForDispatchCard(order: order, strings: strings),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown before the seller has started delivering — no live point to plot
/// yet, so a floating, oddly-zoomed empty map does more harm than good.
/// Instead, a clean card confirming the delivery address, matching the
/// same visual language as the order summary above it.
class _WaitingForDispatchCard extends StatelessWidget {
  final Order order;
  final AppStrings strings;
  const _WaitingForDispatchCard({required this.order, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
            child: const Icon(Icons.location_on_rounded, color: AppColors.green, size: 26),
          ),
          const SizedBox(height: 12),
          if (order.deliveryAddressLabel != null)
            Text(order.deliveryAddressLabel!,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            order.status == OrderStatus.confirmed ? strings.statusConfirmedLabel : strings.statusPlacedLabel,
            style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final Order order;
  final AppStrings strings;
  const _OrderSummaryCard({required this.order, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item.nameHi} ×${item.quantity}',
                          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text('₹${item.lineTotal}', style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('कुल', style: AppTextStyles.display(fontSize: 15)),
              Text('₹${order.totalValue}', style: AppTextStyles.display(fontSize: 15)),
            ],
          ),
          if (order.assignedMerchantName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 14, color: AppColors.mutedDark),
                const SizedBox(width: 6),
                Text(order.assignedMerchantName!, style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingMap extends StatefulWidget {
  final latlng.LatLng deliveryPoint;
  final latlng.LatLng? livePoint;
  const _TrackingMap({required this.deliveryPoint, this.livePoint});

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(_TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-follow the seller as they move — the buyer never has to pan
    // or zoom themselves to keep up, which matters a lot for someone
    // who's never used a map app before.
    final point = widget.livePoint;
    if (point != null && point != oldWidget.livePoint) {
      _mapController.move(point, _mapController.camera.zoom);
    }
  }

  double _distanceKm() {
    final live = widget.livePoint;
    if (live == null) return 0;
    const earthRadiusKm = 6371.0;
    double toRad(double d) => d * math.pi / 180;
    final dLat = toRad(widget.deliveryPoint.latitude - live.latitude);
    final dLng = toRad(widget.deliveryPoint.longitude - live.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(live.latitude)) * math.cos(toRad(widget.deliveryPoint.latitude)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.livePoint ?? widget.deliveryPoint,
            initialZoom: 16,
            // Rotation is the one gesture that reliably confuses anyone
            // who hasn't used a map app before (the whole view spins) —
            // pan/zoom stay on since they're intuitive enough.
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gaonhaat.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.deliveryPoint,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.home, color: AppColors.green, size: 36),
                ),
                if (widget.livePoint != null)
                  Marker(
                    point: widget.livePoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.two_wheeler, color: Color(0xFFC0453B), size: 36),
                  ),
              ],
            ),
          ],
        ),
        if (widget.livePoint != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.two_wheeler, size: 16, color: Color(0xFFC0453B)),
                  const SizedBox(width: 8),
                  Text('~${_distanceKm().toStringAsFixed(1)} km दूर',
                      style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Order Placed ✓ → Confirmed ✓ → Out for Delivery → Delivered" strip.
/// Cancelled short-circuits to its own single-line state.
class _StatusTimeline extends StatelessWidget {
  final Order order;
  final AppStrings strings;
  const _StatusTimeline({required this.order, required this.strings});

  List<(OrderStatus, String, IconData)> _steps() => [
        (OrderStatus.placed, strings.statusPlacedLabel, Icons.receipt_long_rounded),
        (OrderStatus.confirmed, strings.statusConfirmedLabel, Icons.check_circle_outline_rounded),
        (OrderStatus.outForDelivery, strings.statusOutForDeliveryLabel, Icons.two_wheeler_rounded),
        (OrderStatus.delivered, strings.statusDeliveredLabel, Icons.home_rounded),
      ];

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFC0453B).withOpacity(0.08),
        child: Text(strings.orderCancelledMessage,
            style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFC0453B))),
      );
    }

    final steps = _steps();
    final currentIndex = steps.indexWhere((s) => s.$1 == order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length, (i) {
          final (_, label, icon) = steps[i];
          final isDone = i <= currentIndex;
          final isLast = i == steps.length - 1;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.green : AppColors.inactive.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: isDone ? Colors.white : AppColors.mutedDark),
                    ),
                    const SizedBox(height: 6),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(
                          fontSize: 10,
                          fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                          color: isDone ? AppColors.green : AppColors.mutedDark,
                        )),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: i < currentIndex ? AppColors.green : AppColors.inactive.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Ticks down live using createdAt + etaMinutes from the order. Rebuilds
/// every 30s — cheap to recompute locally, no need to re-hit Firestore.
/// Hides itself entirely if the order has no ETA (e.g. no merchant could
/// be assigned yet) rather than showing a blank/broken bar.
class _EtaCountdown extends StatefulWidget {
  final Order order;
  final AppStrings strings;
  const _EtaCountdown({required this.order, required this.strings});

  @override
  State<_EtaCountdown> createState() => _EtaCountdownState();
}

class _EtaCountdownState extends State<_EtaCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etaMinutes = widget.order.etaMinutes;
    if (etaMinutes == null) return const SizedBox.shrink();

    final expectedArrival = widget.order.createdAt.add(Duration(minutes: etaMinutes));
    final remainingMinutes = expectedArrival.difference(DateTime.now()).inMinutes;

    final label = remainingMinutes > 1
        ? widget.strings.etaMinutesLabel(remainingMinutes)
        : remainingMinutes >= 0
            ? widget.strings.etaArrivingSoon
            : widget.strings.etaMayArriveAnytime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.mustard.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 16, color: AppColors.mutedDark),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
