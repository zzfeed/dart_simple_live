import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';

class AccountController extends GetxController {
  Future<String?> cookieInputDialog({
    required String title,
    required List<String> fields,
    void Function(Map<String, TextEditingController>)? onParse,
  }) async {
    final controllers = {
      for (var f in fields) f: TextEditingController(),
      'full': TextEditingController(),
    };

    void parseCookie(String raw) {
      final cookie = raw.replaceAll(
        RegExp(
          r"["
          ''
          "]",
        ),
        '',
      );
      final parts = cookie.split(';');
      for (var part in parts) {
        final kv = part.trim().split('=');
        if (kv.length < 2) continue;
        final key = kv[0].trim();
        final value = kv.sublist(1).join('=').trim();
        if (controllers.containsKey(key)) {
          controllers[key]!.text = value;
        }
      }
      if (onParse != null) onParse(controllers);
    }

    InputDecoration inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      );
    }

    return Get.dialog<String>(
      AlertDialog(
        title: Text('手动输入 $title Cookie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controllers['full'],
                decoration: inputDecoration('粘贴完整 Cookie（自动解析）'),
                maxLines: 2,
                onChanged: parseCookie,
              ),
              AppStyle.vGap12,
              ...fields.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[f],
                    decoration: inputDecoration(f),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final values = {
                for (var f in fields) f: controllers[f]!.text.trim(),
              };
              // if (values.values.any((e) => e.isEmpty)) {
              //   SmartDialog.showToast('请完整填写所有字段');
              //   return;
              // }
              final cookie = values.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('; ');
              Get.back(result: cookie);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> bilibiliTap() async {
    if (BiliBiliAccountService.instance.logged.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get
                  ..back()
                  ..toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get
                ..back()
                ..toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Get.back();
              final cookie = await cookieInputDialog(
                title: "哔哩哔哩",
                fields: [
                  'SESSDATA',
                  'bili_jct',
                  'DedeUserID',
                  'DedeUserID__ckMd5',
                  'sid',
                  'buvid3',
                  'buvid4',
                ],
              );
              if (cookie?.isNotEmpty ?? false) {
                BiliBiliAccountService.instance
                  ..setCookie(cookie!)
                  ..loadUserInfo();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> douyinTap() async {
    if (DouyinAccountService.instance.logged.value) {
      var result = await Utils.showAlertDialog(
        "确定要清除抖音Cookie吗？",
        title: "清除Cookie",
      );
      if (result) {
        DouyinAccountService.instance.logout();
      }
    } else {
      final cookie = await cookieInputDialog(
        title: "抖音",
        fields: [
          'ttwid',
          '__ac_nonce',
          '__ac_signature',
          'sessionid',
          'uid_tt',
        ],
      );

      if (cookie?.isNotEmpty ?? false) {
        DouyinAccountService.instance
          ..setCookie(cookie!)
          ..loadUserInfo();
      }
    }
  }
}
