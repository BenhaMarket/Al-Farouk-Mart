import 'dart:async';

import 'package:alfarouk_mart/Screen/FlashSale.dart';
import 'package:alfarouk_mart/Helper/Color.dart';
import 'package:alfarouk_mart/Helper/PushNotificationService.dart';
import 'package:alfarouk_mart/Helper/Session.dart';
import 'package:alfarouk_mart/Helper/SqliteData.dart';
import 'package:alfarouk_mart/Helper/String.dart';
import 'package:alfarouk_mart/Model/Section_Model.dart';
import 'package:alfarouk_mart/Provider/HomeProvider.dart';
import 'package:alfarouk_mart/Provider/UserProvider.dart';
import 'package:alfarouk_mart/Screen/Cart.dart';
import 'package:alfarouk_mart/Screen/Favorite.dart';
import 'package:alfarouk_mart/Screen/Login.dart';
import 'package:alfarouk_mart/Screen/MyProfile.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:bottom_bar/bottom_bar.dart';

import '../Provider/SettingProvider.dart';
import '../ui/styles/DesignConfig.dart';
import 'All_Category.dart';

import 'HomePage.dart';
import 'NotificationLIst.dart';
import 'Product_DetailNew.dart';
import 'Sale.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _HomePageState();
}

class _HomePageState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  int _selBottom = 0;

  final PageController _pageController = PageController();
  bool _isNetworkAvail = true;
  var db = DatabaseHelper();
  late AnimationController navigationContainerAnimationController =
      AnimationController(
    vsync: this, // the SingleTickerProviderStateMixin
    duration: const Duration(milliseconds: 500),
  );
  FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

  @override
  void initState() {
    super.initState();
    initDynamicLinks();
    db.getTotalCartCount(context);
    final pushNotificationService = PushNotificationService(
        context: context, pageController: _pageController);
    pushNotificationService.initialise();

    Future.delayed(Duration.zero, () async {
      SettingProvider settingsProvider =
          Provider.of<SettingProvider>(context, listen: false);
      CUR_USERID = await settingsProvider.getPrefrence(ID) ?? '';
      context
          .read<HomeProvider>()
          .setAnimationController(navigationContainerAnimationController);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selBottom != 0) {
          _pageController.animateToPage(0,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut);
          return false;
        }
        return true;
      },
      child: SafeArea(
        top: false,
        bottom: true,
        child: Scaffold(
          extendBody: true,
          backgroundColor: Theme.of(context).colorScheme.lightWhite,
          appBar: _getAppBar(),
          body: PageView(
            controller: _pageController,
            children: const [
              HomePage(),
              // AllCategory(),
              FlashSale(),
              // Sale(),
              Cart(
                fromBottom: true,
              ),
              MyProfile()
            ],
            onPageChanged: (index) {
              setState(() {
                if (!context
                    .read<HomeProvider>()
                    .animationController
                    .isAnimating) {
                  context.read<HomeProvider>().animationController.reverse();
                  context.read<HomeProvider>().showBars(true);
                }
                _selBottom = index;
                if (index == 1) {
                  cartTotalClear();
                }
              });
            },
          ),
          bottomNavigationBar: _getBottomBar(),
        ),
      ),
    );
  }

  void initDynamicLinks() async {
    dynamicLinks.onLink.listen((dynamicLinkData) {
      final Uri deepLink = dynamicLinkData.link;

      if (deepLink.queryParameters.isNotEmpty) {
        int index = int.parse(deepLink.queryParameters['index']!);

        int secPos = int.parse(deepLink.queryParameters['secPos']!);

        String? id = deepLink.queryParameters['id'];

        String? list = deepLink.queryParameters['list'];

        getProduct(id!, index, secPos, list == "true" ? true : false);
      }
    }).onError((e) {
      print(e.message);
    });

    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri? deepLink = data?.link;
    if (deepLink != null) {
      if (deepLink.queryParameters.isNotEmpty) {
        int index = int.parse(deepLink.queryParameters['index']!);

        int secPos = int.parse(deepLink.queryParameters['secPos']!);

        String? id = deepLink.queryParameters['id'];

        getProduct(id!, index, secPos, true);
      }
    }
  }

  Future<void> getProduct(String id, int index, int secPos, bool list) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        var parameter = {
          ID: id,
        };

        apiBaseHelper.postAPICall(getProductApi, parameter).then((getdata) {
          bool error = getdata["error"];
          String msg = getdata["message"];
          if (!error) {
            var data = getdata["data"];

            List<Product> items = [];

            items =
                (data as List).map((data) => Product.fromJson(data)).toList();
            currentHero = homeHero;
            Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) => ProductDetail(
                      index: list ? int.parse(id) : index,
                      id: list
                          ? items[0].id!
                          : sectionList[secPos].productList![index].id!,
                      secPos: secPos,
                      list: list,
                    )));
          } else {
            if (msg != "Products Not Found !") setSnackbar(msg, context);
          }
        }, onError: (error) {
          setSnackbar(error.toString(), context);
        });
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      {
        if (mounted) {
          setState(() {
            setSnackbar(getTranslated(context, 'NO_INTERNET_DISC')!, context);
          });
        }
      }
    }
  }

  AppBar _getAppBar() {
    String? title;
    // if (_selBottom == 1) {
    //   title = getTranslated(context, 'CATEGORY');
    // } else if (_selBottom == 2) {
    //   title = getTranslated(context, 'OFFER');
    // } else if (_selBottom == 3) {
    //   title = getTranslated(context, 'MYBAG');
    // } else if (_selBottom == 4) {
    //   title = getTranslated(context, 'PROFILE');
    // }
    if (_selBottom == 1) {
      title = getTranslated(context, 'OFFER');
    } else if (_selBottom == 2) {
      title = getTranslated(context, 'MYBAG');
    } else if (_selBottom == 3) {
      title = getTranslated(context, 'PROFILE');
    }

    return AppBar(
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: _selBottom == 0
          ? Row(
            children: [
              SvgPicture.asset(
                  'assets/images/titleiconlogo.svg',
                  height: 35,
                ),
              Image.asset(
                'assets/images/titleiconname.png',
                height: 35,
              ),
            ],
          )
          : Text(
              title!,
              style: const TextStyle(
                  color: colors.primary, fontWeight: FontWeight.normal),
            ),
      actions: <Widget>[
        IconButton(
          icon: SvgPicture.asset(
            "${imagePath}desel_notification.svg",
            color: colors.primary,
          ),
          onPressed: () {
            CUR_USERID != null
                ? Navigator.push<bool>(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const NotificationList(),
                    )).then((value) {
                    if (value != null && value) {
                      _pageController.jumpToPage(1);
                    }
                  })
                : Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const Login(),
                    ));
          },
        ),
        IconButton(
          padding: const EdgeInsets.all(0),
          icon: SvgPicture.asset(
            "${imagePath}desel_fav.svg",
            color: colors.primary,
          ),
          onPressed: () {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const Favorite(),
                ));
          },
        ),
      ],
      backgroundColor: Theme.of(context).colorScheme.lightWhite,
    );
  }

  Widget _getBottomBar() {
    return FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
            parent: navigationContainerAnimationController,
            curve: Curves.easeInOut)),
        child: SlideTransition(
          position:
              Tween<Offset>(begin: Offset.zero, end: const Offset(0.0, 1.0))
                  .animate(CurvedAnimation(
                      parent: navigationContainerAnimationController,
                      curve: Curves.easeInOut)),
          child: Container(
            height: kBottomNavigationBarHeight,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.white,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20))),
            child: BottomBar(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
              duration: const Duration(milliseconds: 1000),
              itemPadding: const EdgeInsets.all(10),
              curve: Curves.easeInOut,
              selectedIndex: _selBottom,
              onTap: (int index) {
                _pageController.jumpToPage(index);
                setState(() => _selBottom = index);
              },

              //itemPadding: EdgeInsets.zero,
              items: <BottomBarItem>[
                BottomBarItem(
                  icon: _selBottom == 0
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: SvgPicture.asset(
                            "${imagePath}sel_home.svg",
                            color: colors.primary,
                            width: 18,
                          ),
                      )
                      : SvgPicture.asset(
                          "${imagePath}desel_home.svg",
                          color: colors.primary,
                          width: 18,
                        ),
                  title: Text(
                      getTranslated(
                        context,
                        'HOME_LBL',
                      )!,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true),
                  activeColor: colors.primary,
                ),
                // BottomBarItem(
                //     icon: _selBottom == 1
                //         ? Padding(
                //           padding: const EdgeInsets.symmetric(horizontal: 10.0),
                //           child: SvgPicture.asset(
                //               "${imagePath}category01.svg",
                //               color: colors.primary,
                //               width: 18,
                //             ),
                //         )
                //         : SvgPicture.asset(
                //             "${imagePath}category.svg",
                //             color: colors.primary,
                //             width: 18,
                //           ),
                //     title: Text(
                //         getTranslated(context, 'category')!,
                //         overflow: TextOverflow.ellipsis,
                //         softWrap: true),
                //     activeColor: colors.primary),
                BottomBarItem(
                  icon: _selBottom == 1
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: SvgPicture.asset(
                            "${imagePath}sale02.svg",
                            color: colors.primary,
                            width: 18,
                          ),
                      )
                      : SvgPicture.asset(
                          "${imagePath}sale.svg",
                          color: colors.primary,
                          width: 18,
                        ),
                  title: Text(getTranslated(context, 'SALE')!,
                      overflow: TextOverflow.ellipsis, softWrap: true),
                  activeColor: colors.primary,
                ),
                BottomBarItem(
                  icon: Selector<UserProvider, String>(
                    builder: (context, data, child) {
                      return Stack(
                        children: [
                          _selBottom == 2
                              ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                                child: SvgPicture.asset(
                                    "${imagePath}cart01.svg",
                                    color: colors.primary,
                                    width: 18,
                                  ),
                              )
                              : SvgPicture.asset(
                                  "${imagePath}cart.svg",
                                  color: colors.primary,
                                  width: 18,
                                ),
                          (data.isNotEmpty && data != "0")
                              ? Positioned.directional(
                                  end: 0,
                                  textDirection: Directionality.of(context),
                                  top: -3,
                                  child: Container(
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.primary),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(3),
                                          child: Text(
                                            data,
                                            style: TextStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .white),
                                          ),
                                        ),
                                      )),
                                )
                              : Container()
                        ],
                      );
                    },
                    selector: (_, homeProvider) => homeProvider.curCartCount,
                  ),
                  title: Text(getTranslated(context, 'CART')!,
                      overflow: TextOverflow.ellipsis, softWrap: true),
                  activeColor: colors.primary,
                ),
                BottomBarItem(
                  icon: _selBottom == 3
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: SvgPicture.asset(
                            "${imagePath}profile01.svg",
                            color: colors.primary,
                            width: 18,
                          ),
                      )
                      : SvgPicture.asset(
                          "${imagePath}profile.svg",
                          width: 18,
                          color: colors.primary,
                        ),
                  title: Text(getTranslated(context, 'PROFILE')!,
                      overflow: TextOverflow.ellipsis, softWrap: true),
                  activeColor: colors.primary,
                ),
              ],
            ),
          ),
        ));
  }

}
