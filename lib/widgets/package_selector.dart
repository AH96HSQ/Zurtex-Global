import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class PackageSelector extends StatefulWidget {
  final void Function(int days, int gb)? onChanged;
  final int pricePerDay;
  final int pricePerGB;

  const PackageSelector({
    super.key,
    this.onChanged,
    this.pricePerDay = 400,
    this.pricePerGB = 3000,
  });

  @override
  State<PackageSelector> createState() => _PackageSelectorState();
}

class _PackageSelectorState extends State<PackageSelector> {
  double selectedDays = 30;
  double selectedGB = 30;
  String formatWithSpaces(int number) {
    final str = number.toString();
    final buffer = StringBuffer();

    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  void notifyParent() {
    if (widget.onChanged != null) {
      widget.onChanged!(selectedDays.toInt(), selectedGB.toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedDays.toInt()} روز اشتراک',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${formatWithSpaces(selectedDays.toInt() * widget.pricePerDay)} تومان',
                    style: const TextStyle(
                      color: Color(0xFF56A6E7),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SfSlider(
            min: 7,
            max: 180,
            value: selectedDays,
            interval: 30,
            showTicks: false,
            showLabels: false,
            enableTooltip: false,
            stepSize: 1,
            activeColor: Color(0xFF56A6E7), // ← selected range color
            inactiveColor: Color(0xFF444444), // ← unselected range color
            onChanged: (value) {
              setState(() => selectedDays = value);
              notifyParent();
            },
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 25,
            ), // ← adjust as needed
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedGB.toInt()} گیگابایت حجم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${formatWithSpaces(selectedGB.toInt() * widget.pricePerGB)} تومان',
                    style: const TextStyle(
                      color: Color(0xFF56A6E7),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SfSlider(
            min: 15,
            max: 150,
            value: selectedGB,
            interval: 50,
            showTicks: false,
            showLabels: false,
            enableTooltip: false,
            stepSize: 1,
            activeColor: Color(0xFF56A6E7), // ← selected range color
            inactiveColor: Color(0xFF444444), // ← unselected range color
            onChanged: (value) {
              setState(() => selectedGB = value);
              notifyParent();
            },
          ),
        ],
      ),
    );
  }
}
