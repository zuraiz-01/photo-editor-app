import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Editor')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Select an image to start editing',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3.h),
              Obx(
                () => SizedBox(
                  width: 70.w,
                  child: FilledButton(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.pickFromGallery,
                    child: const Text('Pick from Gallery'),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Obx(
                () => SizedBox(
                  width: 70.w,
                  child: OutlinedButton(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.pickFromCamera,
                    child: const Text('Capture from Camera'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
