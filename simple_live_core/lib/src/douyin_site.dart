import 'dart:convert';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/douyin/douyin_utils.dart';
import 'package:simple_live_core/src/common/http_client.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  String cookie = "";

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      final headers = <String, String>{
        "authority": DouyinUtils.kDefaultAuthority,
        "referer": DouyinUtils.kDefaultReferer,
        "user-agent": DouyinUtils.kDefaultUserAgent,
        "cookie": cookie,
      };

      String cookies = headers['cookie'] ?? '';

      final extraCookies = <String>[];

      if (!cookies.contains('ttwid')) {
        final ttwid = await DouyinUtils.getTtwid();
        if (ttwid != null && ttwid.isNotEmpty) {
          extraCookies.add('ttwid=$ttwid');
        }
      }

      // if (!cookies.contains('msToken')) {
      //   extraCookies.add('msToken=${DouyinUtils.generateMsToken()}');
      // }

      if (!cookies.contains('__ac_nonce=')) {
        extraCookies.add('__ac_nonce=${DouyinUtils.generateNonce()}');
      }

      if (!cookies.contains('odin_tt')) {
        extraCookies.add('odin_tt=${DouyinUtils.generateOdinTtid()}');
      }

      if (extraCookies.isNotEmpty) {
        cookies = [
          ...extraCookies,
          cookies,
        ].where((e) => e.isNotEmpty).join('; ');
      }

      headers['cookie'] = cookies;

      return headers;
    } catch (e) {
      CoreLog.error(e);
      return {
        "Authority": DouyinUtils.kDefaultAuthority,
        "Referer": DouyinUtils.kDefaultReferer,
        "User-Agent": DouyinUtils.kDefaultUserAgent,
      };
    }
  }

  @override
  Future<List<LiveCategory>> getCategories() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    var renderData =
        RegExp(
          r'\{\\"pathname\\":\\"\/\\",\\"categoryData.*?\]\\n',
        ).firstMatch(result)?.group(0) ??
        "";
    var renderDataJson = json.decode(
      renderData
          .trim()
          .replaceAll('\\"', '"')
          .replaceAll(r"\\", r"\")
          .replaceAll(']\\n', ""),
    );

    for (var item in renderDataJson["categoryData"]) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
        0,
        LiveSubCategory(
          id: category.id,
          name: category.name,
          parentId: category.id,
          pic: "",
        ),
      );
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var ids = category.id.split(',');
    var partitionId = ids[0];
    var partitionType = ids[1];

    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var queryParams = {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "enter_from": "link_share",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "browser_online": "true",
      "count": '15',
      "offset": ((page - 1) * 15).toString(),
      "partition": partitionId,
      "partition_type": partitionType,
      "req_from": '2',
    };

    var targetUrl = await DouyinUtils.buildRequestUrl(
      serverUrl,
      query: queryParams,
    );

    var result = await HttpClient.instance.getJson(
      targetUrl,
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        areaName: item["tag_name"].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online:
            int.tryParse(
              item["room"]["room_view_stats"]["display_value"].toString(),
            ) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";

    var queryParams = {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "language": "zh-CN",
      "enter_from": "link_share",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "browser_online": "true",
      "count": '15',
      "offset": ((page - 1) * 15).toString(),
      "partition": '720',
      "partition_type": '1',
      "req_from": '2',
    };

    var targetUrl = await DouyinUtils.buildRequestUrl(
      serverUrl,
      query: queryParams,
    );

    var result = await HttpClient.instance.getJson(
      targetUrl,
      header: await getRequestHeaders(),
    );

    var data = result["data"]["data"] as List;

    var hasMore = data.length >= 15;

    var items = <LiveRoomItem>[];
    for (var i in data) {
      var item = i["room"];
      var roomItem = LiveRoomItem(
        roomId: item["owner"]["web_rid"],
        title: item["title"].toString(),
        cover: item["cover"]["url_list"][0].toString(),
        areaName: "",
        userName: item["owner"]["nickname"].toString(),
        online:
            int.tryParse(item["room_view_stats"]["display_value"].toString()) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    // 有两种roomId，一种是webRid，一种是roomId
    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // roomId一般长度为19位，例如：7376429659866598196
    // webRid是固定的，用户每次开播都是同一个webRid
    // webRid一般长度为11-12位，例如：416144012050
    // 这里简单进行判断，如果roomId长度小于15，则认为是webRid
    if (roomId.length <= 16) {
      var webRid = roomId;
      return await getRoomDetailByWebRid(webRid);
    }

    return await getRoomDetailByRoomId(roomId);
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);

    // 通过房间信息获取WebRid
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = DouyinUtils.randomString(12);

    var room = roomData["data"]["room"];
    var owner = room["owner"];

    var status = asT<int?>(room["status"]) ?? 0;

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      areaName: "",
      userName: owner["nickname"].toString(),
      userAvatar: owner["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: room["stream_url"],
    );
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e) {
      CoreLog.error(e);
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);
    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();

    var partitionTitle = data["partition_road_map"]?["partition"]?["title"]
        ?.toString();
    var subPartitionTitle =
        data["partition_road_map"]?["sub_partition"]?["partition"]?["title"]
            ?.toString();

    var areaName = (subPartitionTitle != null && subPartitionTitle.isNotEmpty)
        ? subPartitionTitle
        : (partitionTitle ?? "");

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = DouyinUtils.randomString(12);

    var owner = roomData["owner"];

    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();
    return LiveRoomDetail(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      areaName: areaName,
      userName: roomStatus
          ? owner["nickname"].toString()
          : userData["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(roomData["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidHtml(String webRid) async {
    var roomData = await _getRoomDataByHtml(webRid);
    var roomId = roomData["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    var userUniqueId = roomData["userStore"]["odin"]["user_unique_id"]
        .toString();

    var room = roomData["roomStore"]["roomInfo"]["room"];
    var owner = room["owner"];
    var anchor = roomData["roomStore"]["roomInfo"]["anchor"];
    var roomStatus = (asT<int?>(room["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      areaName: "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : anchor["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : anchor["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? room["stream_url"] : {},
    );
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return webInfo["userStore"]["odin"]["user_unique_id"].toString();
    } catch (e) {
      return DouyinUtils.randomString(12);
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  // Future<String> _getWebCookie(String webRid) async {
  //   var headResp = await HttpClient.instance.head(
  //     "https://live.douyin.com/$webRid",
  //     header: await getRequestHeaders(),
  //   );
  //   var dyCookie = "";
  //   headResp.headers["set-cookie"]?.forEach((element) {
  //     var cookie = element.split(";")[0];
  //     if (cookie.contains("ttwid")) {
  //       dyCookie += "$cookie;";
  //     }
  //     if (cookie.contains("__ac_nonce")) {
  //       dyCookie += "$cookie;";
  //     }
  //     if (cookie.contains("msToken")) {
  //       dyCookie += "$cookie;";
  //     }
  //   });
  //   return dyCookie;
  // }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    var renderData =
        RegExp(
          r'\{\\"state\\":\{\\"appStore.*?\]\\n',
        ).firstMatch(result)?.group(0) ??
        "";
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    var renderDataJson = json.decode(str);
    return renderDataJson["state"];
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";

    var queryParams = {
      "aid": '6383',
      "app_name": "douyin_web",
      "live_id": '1',
      "device_platform": "web",
      "enter_from": "web_live",
      "web_rid": webRid,
      "room_id_str": "",
      "enter_source": "",
      "Room-Enter-User-Login-Ab": '0',
      "is_need_double_stream": 'false',
      "cookie_enabled": 'true',
      "screen_width": '1980',
      "screen_height": '1080',
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
    };

    var targetUrl = await DouyinUtils.buildRequestUrl(
      serverUrl,
      query: queryParams,
    );

    var result = await HttpClient.instance.getJson(
      targetUrl,
      header: await getRequestHeaders(),
    );
    return result["data"];
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    return result;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities({
    required LiveRoomDetail detail,
  }) async {
    List<LivePlayQuality> qualities = [];

    var qualityList =
        detail.data["live_core_sdk_data"]["pull_data"]["options"]["qualities"];
    var streamData = detail
        .data["live_core_sdk_data"]["pull_data"]["stream_data"]
        .toString();

    if (!streamData.startsWith('{')) {
      var flvList = (detail.data["flv_pull_url"] as Map).values
          .cast<String>()
          .toList();
      var hlsList = (detail.data["hls_pull_url_map"] as Map).values
          .cast<String>()
          .toList();
      for (var quality in qualityList) {
        int level = quality["level"];
        List<String> urls = [];
        var flvIndex = flvList.length - level;
        if (flvIndex >= 0 && flvIndex < flvList.length) {
          urls.add(flvList[flvIndex]);
        }
        var hlsIndex = hlsList.length - level;
        if (hlsIndex >= 0 && hlsIndex < hlsList.length) {
          urls.add(hlsList[hlsIndex]);
        }
        var qualityItem = LivePlayQuality(
          quality: quality["name"],
          sort: level,
          data: urls,
        );
        if (urls.isNotEmpty) {
          qualities.add(qualityItem);
        }
      }
    } else {
      var qualityData = json.decode(streamData)["data"] as Map;
      for (var quality in qualityList) {
        List<String> urls = [];
        var flvUrl = qualityData[quality["sdk_key"]]?["main"]?["flv"]
            ?.toString();

        if (flvUrl != null && flvUrl.isNotEmpty) {
          urls.add(flvUrl);
        }
        var hlsUrl = qualityData[quality["sdk_key"]]?["main"]?["hls"]
            ?.toString();
        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          urls.add(hlsUrl);
        }
        var qualityItem = LivePlayQuality(
          quality: quality["name"],
          sort: quality["level"],
          data: urls,
        );
        if (urls.isNotEmpty) {
          qualities.add(qualityItem);
        }
      }
    }
    // var qualityData = json.decode(
    //     detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    return LivePlayUrl(urls: quality.data);
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    String serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/";
    const count = 20;
    var queryParams = {
      "device_platform": "webapp",
      "aid": "6383",
      "channel": "channel_pc_web",
      "search_channel": "aweme_live",
      "keyword": keyword,
      "search_source": "switch_tab",
      "query_correct_type": "1",
      "is_filter_search": "0",
      "from_group_id": "",
      "offset": ((page - 1) * count).toString(),
      "count": "$count",
      "pc_client_type": "1",
      "version_code": "170400",
      "version_name": "17.4.0",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "125.0.0.0",
      "browser_online": "true",
      "engine_name": "Blink",
      "engine_version": "125.0.0.0",
      "os_name": "Windows",
      "os_version": "10",
      "cpu_core_num": "12",
      "device_memory": "8",
      "platform": "PC",
      "downlink": "10",
      "effective_type": "4g",
      "round_trip_time": "100",
      "webid": "7382872326016435738",
    };
    var requestUrl = Uri.parse(serverUrl).replace(queryParameters: queryParams);
    var headers = Map<String, String>.from(await getRequestHeaders());

    final signature = DouyinUtils.generateAcSignature(
      Uri.parse(serverUrl).path,
      headers["cookie"]![2].toString(),
      DouyinUtils.kDefaultUserAgent,
    );

    if (!headers["cookie"]!.contains('__ac_signature')) {
      headers["cookie"] = '${headers["cookie"]}; __ac_signature=$signature';
    }

    headers.addAll({
      'authority': 'www.douyin.com',
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'priority': 'u=1, i',
      'sec-ch-ua':
          '"Microsoft Edge";v="125", "Chromium";v="125", "Not.A/Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'referer':
          'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live',
    });

    final result = await HttpClient.instance.getJson(
      requestUrl.toString(),
      header: headers,
    );

    if (result == null || result == "" || result == 'blocked') {
      throw Exception("抖音直播搜索被限制，请稍后再试");
    }
    if (result["search_nil_info"] != null) {
      throw Exception("抖音直播搜索被限制，需要验证滑块验证码");
    }
    if (result["status_code"] != 0) {
      throw Exception(result["status_msg"].toString());
    }
    var items = <LiveRoomItem>[];
    for (var item in result["data"] ?? []) {
      var itemData = json.decode(item["lives"]["rawdata"].toString());
      var roomItem = LiveRoomItem(
        roomId: itemData["owner"]["web_rid"].toString(),
        title: itemData["title"].toString(),
        cover: itemData["cover"]["url_list"][0].toString(),
        areaName: "",
        userName: itemData["owner"]["nickname"].toString(),
        online: int.tryParse(itemData["stats"]["total_user"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: items.length >= 10, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    throw Exception("抖音暂不支持搜索主播，请直接搜索直播间");
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId);
    return result.status;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
  }) {
    return Future.value(<LiveSuperChatMessage>[]);
  }
}
