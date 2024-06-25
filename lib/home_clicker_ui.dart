import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeClickerUi extends StatefulWidget {
  const HomeClickerUi({super.key});

  @override
  State<HomeClickerUi> createState() => _HomeClickerUiState();
}

class _HomeClickerUiState extends State<HomeClickerUi>
    with TickerProviderStateMixin {
  int _clickCount = 0;
  double _batteryPercentage = 1.0; // 100%
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;
  late Timer _batteryTimer;
  bool _recharging = false;
  DateTime? _appClosedTime;
  DateTime? _appOpenedTime;
  @override
  void initState() {
    super.initState();

    _loadClickCount();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Lifecycle listener methods
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _appClosedTime = DateTime.now();
      _saveAppClosedTime();
    } else if (state == AppLifecycleState.resumed) {
      _appOpenedTime = DateTime.now();
      _saveAppOpenedTime();

      // Calculate and update battery percentage based on closed-open duration
      _updateBatteryPercentage();
    }
  }

  // Load the battery percentage from shared preferences
  void _loadBatteryPercentage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _batteryPercentage = prefs.getDouble('batteryPercentage') ?? 1.0;
    });
  }

  // Save the app closed time to SharedPreferences
  void _saveAppClosedTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appClosedTime', _appClosedTime!.millisecondsSinceEpoch);
  }

  // Save the app opened time to SharedPreferences
  void _saveAppOpenedTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appOpenedTime', _appOpenedTime!.millisecondsSinceEpoch);
  }

  // Calculate and update battery percentage based on closed-open duration
  void _updateBatteryPercentage() async {
    final prefs = await SharedPreferences.getInstance();
    final int? closedTimeMillis = prefs.getInt('appClosedTime');
    final int? openedTimeMillis = prefs.getInt('appOpenedTime');
    if (closedTimeMillis != null && openedTimeMillis != null) {
      final Duration closedOpenDuration =
          Duration(milliseconds: openedTimeMillis - closedTimeMillis);
      final double chargeAmount = closedOpenDuration.inSeconds * 0.0008;

      setState(() {
        _batteryPercentage += chargeAmount;

        // Ensure battery percentage doesn't exceed 1.0 (100%)
        if (_batteryPercentage > 1.0) {
          _batteryPercentage = 1.0;
        }

        // Save battery percentage to SharedPreferences
        prefs.setDouble('batteryPercentage', _batteryPercentage);
      });
    }
  }

  void _loadClickCount() async {
    final pref = await SharedPreferences.getInstance();
    setState(() {
      _clickCount = pref.getInt("clickCount") ?? 0;
    });
  }

  void _incrementClickCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (_batteryPercentage > 0.001) {
      setState(() {
        _clickCount += 1;
        prefs.setInt("clickCount", _clickCount);
        _batteryPercentage -= 0.003;
        if (!_recharging) {
          _startBatteryRechargeTimer();
        }
      });
      _controller.forward(from: 0);
    }
  }

  void _startBatteryRechargeTimer() {
    const rechargeInterval = Duration(seconds: 1);

    _batteryTimer = Timer.periodic(rechargeInterval, (timer) {
      setState(() {
        if (_batteryPercentage < 1.0) {
          _recharging = true;
          _batteryPercentage += 0.0008;
        }
        if (_batteryPercentage >= 1.0) {
          _recharging = false;
          _batteryPercentage = 1.0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/background.jpg"), fit: BoxFit.cover),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "AstroCoins:",
              style: Theme.of(context)
                  .textTheme
                  .displayLarge!
                  .copyWith(color: Colors.white),
            ),
            Text(
              "$_clickCount",
              style: const TextStyle(
                fontSize: 65,
                color: Colors.white,
              ),
            ),
            SizedBox(
              height: height * 0.1,
            ),
            Stack(
              children: [
                InkWell(
                  onTap: _incrementClickCount,
                  child: Image.asset(
                    'assets/astrocoin.png',
                    height: height * 0.35,
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _opacityAnimation,
                        child: SlideTransition(
                          position: _offsetAnimation,
                          child: Center(
                            child: Text(
                              '+1',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge!
                                  .copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
            SizedBox(
              height: height * 0.1,
            ),
            _buildBatteryIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.02),
          child: Row(
            children: [
              Icon(
                Icons.bolt,
                color: Colors.yellow.shade800,
                size: width * 0.07,
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: _batteryPercentage,
                  borderRadius: BorderRadius.circular(width * 0.02),
                  minHeight: 10,
                  backgroundColor: Colors.amber.shade100,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: height * 0.01),
        Text(
          "Battery: ${(_batteryPercentage * 4000).toInt()}",
          style: const TextStyle(color: Colors.white, fontSize: 20),
        )
      ],
    );
  }
}
