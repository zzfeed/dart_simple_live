import 'dart:math';
import 'package:simple_live_core/src/common/douyin/a_bogus.dart';
import 'package:simple_live_core/src/common/http_client.dart';

class DouyinUtils {
  static String? _douyinTtwid;

  static const aidValue = "6383";
  static const versionCodeValue = "180800";
  static const sdkVersion = "1.0.14-beta.0";

  static const String kDefaultAuthority = "live.douyin.com";
  static const String kDefaultReferer = "https://live.douyin.com";
  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0";

  static const String shortCharset = "abcdef0123456789";
  static const String longCharset =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";

  static Future<String?> getTtwid() async {
    if (_douyinTtwid != null) return _douyinTtwid;

    final response = await HttpClient.instance.getHead(
      "https://live.douyin.com/1-2-3-4-5-6-7-8-9-0",
    );

    final cookiesHeader = response['set-cookie'];
    final cookies = (cookiesHeader is List && cookiesHeader!.isNotEmpty)
        ? cookiesHeader.first
        : '';

    final match = RegExp(r'ttwid=([^;]+)').firstMatch(cookies);
    _douyinTtwid = match?.group(1);

    return _douyinTtwid;
  }

  static String randomString(int length, [String? charset]) {
    final chars = charset ?? shortCharset;
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  static String generateMsToken() => randomString(184, longCharset);
  static String generateNonce() => randomString(21);
  static String generateOdinTtid() => randomString(160);

  static Future<String> buildRequestUrl(
    String url, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(url);

    final params = <String, List<String>>{};
    if (query != null) {
      query.forEach((key, value) {
        params[key] = [value];
      });
    }

    params.addAll({
      'aid': ['6383'],
      // 'compress': ['gzip'],
      // 'device_platform': ['web'],
      'browser_language': ['zh-CN'],
      'browser_platform': ['Win32'],
    });

    final browserName = kDefaultUserAgent.split('/')[0];
    final versionPart = kDefaultUserAgent.split(browserName).last.substring(1);

    params['browser_name'] = [browserName];
    params['browser_version'] = [versionPart];

    params.putIfAbsent('msToken', () => [generateMsToken()]);

    final queryString = params.entries
        .expand(
          (e) => e.value.map(
            (v) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(v)}',
          ),
        )
        .join('&');

    final abogus = ABogus(userAgent: kDefaultUserAgent);
    final result = abogus.generateAbogus(queryString);

    final finalParams = result[0];
    final abogusValue = result[1];

    return '${uri.origin}${uri.path}?$finalParams&abogus=$abogusValue';
  }
}
