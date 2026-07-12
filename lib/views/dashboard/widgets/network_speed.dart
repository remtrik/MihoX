import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/app.dart';
import 'package:mihox/widgets/widgets.dart';

class NetworkSpeed extends StatefulWidget {
  const NetworkSpeed({super.key});

  @override
  State<NetworkSpeed> createState() => _NetworkSpeedState();
}

class _NetworkSpeedState extends State<NetworkSpeed> {
  static const initPoints = [Point(0, 0), Point(1, 0)];

  List<Point> _getPoints(List<Traffic> traffics) => [
        ...initPoints,
        for (var i = 0; i < traffics.length; i++)
          Point(
            (i + initPoints.length).toDouble(),
            traffics[i].speed.toDouble(),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = colorScheme.onSurfaceVariant.opacity80;
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        onPressed: () {},
        info: Info(
          label: appLocalizations.networkSpeed,
          iconData: Icons.speed_sharp,
        ),
        child: Consumer(
          builder: (_, ref, __) {
            final traffics = ref.watch(
              trafficsProvider.select((state) => state.list),
            );
            final lastTraffic =
                traffics.isEmpty ? Traffic() : traffics.last;
            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16).copyWith(
                      bottom: 0,
                      left: 0,
                      right: 0,
                    ),
                    child: RepaintBoundary(
                      child: LineChart(
                        gradient: true,
                        color: colorScheme.primary,
                        points: _getPoints(traffics),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(
                      -16,
                      -20,
                    ),
                    child: Text(
                      "${lastTraffic.up}↑   ${lastTraffic.down}↓",
                      style: context.textTheme.bodySmall?.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}