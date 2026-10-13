import 'package:flutter/material.dart';

/// 全局路由观察者，供页面感知"被上层页面覆盖 / 重新露出"。
///
/// 只观察 [PageRoute]（即 [MaterialPageRoute]、[PageRouteBuilder] 这类全屏页面），
/// 因此 showDialog、showModalBottomSheet 这类 PopupRoute 覆盖不会触发挂起。
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
