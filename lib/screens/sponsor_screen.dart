import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/pressable.dart';

/// 赞助作者：两张收款码（微信 / 支付宝）。
///
/// 关于"自己扫自己"这件事：同一个手机上的 App 显示二维码、自己又没法扫。
/// 可行的两条路是**当面给朋友扫**，或者**截屏后用微信/支付宝的「相册」识别**。
/// 界面里把这两条写清楚，不让人对着屏幕干瞪眼。
class SponsorScreen extends StatelessWidget {
  const SponsorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('赞助作者')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              color: p.jadeSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline, size: 20, color: p.jade),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '日贝是个不联网、不上传、也没有广告的单机 App。\n'
                    '如果它帮到了你，请作者喝杯水就好。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.ink,
                      height: 1.75,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _QrCard(
            asset: 'assets/sponsor/wechat.jpg',
            title: '微信',
            subtitle: '点开可以放大，方便对面扫',
            tint: Color(0xFF07C160),
          ),
          const SizedBox(height: 14),
          const _QrCard(
            asset: 'assets/sponsor/alipay.jpg',
            title: '支付宝',
            subtitle: '点开可以放大，方便对面扫',
            tint: Color(0xFF1677FF),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: p.inkSoft,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        '怎么扫',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '· 当面：把手机递过去，让对方用微信 / 支付宝扫一下。\n'
                    '· 只有一台手机：先截屏这个页面，再打开微信或支付宝的'
                    '「扫一扫 → 相册」，选中刚截的图就行。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.inkSoft,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '谢谢你的支持',
              style: TextStyle(fontSize: 12, color: p.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final String asset;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 顶部色条，一眼分清哪个是微信哪个是支付宝
          Container(height: 4, color: tint),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.qr_code_2,
                        size: 17,
                        color: tint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: p.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.zoom_out_map,
                      size: 17,
                      color: p.inkFaint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 白底是必须的：二维码在深色模式下的深底上扫不出来
                Pressable(
                  scale: 0.97,
                  child: GestureDetector(
                    onTap: () {
                      Haptics.tap();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _QrZoom(
                            asset: asset,
                            title: title,
                            tint: tint,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          // 图片没打进包时不要把整页搞崩
                          errorBuilder: (context, error, stack) => SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                '收款码图片没找到',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.inkFaint,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全屏放大：可以双指缩放、拖动，方便对面慢慢扫
class _QrZoom extends StatelessWidget {
  const _QrZoom({
    required this.asset,
    required this.title,
    required this.tint,
  });

  final String asset;
  final String title;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 固定用白底：这里是给人扫的，不要跟随深色模式
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text('$title 收款码'),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Text(
                '收款码图片没找到',
                style: TextStyle(fontSize: 13, color: tint),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
