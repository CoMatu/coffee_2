import 'dart:math' as math;

import 'package:coffee/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:coffee/sections.dart';
import 'package:coffee/components/widgets.dart';

const Color _kAppBackgroundColor = Colors.brown;
const Duration _kScrollDuration = Duration(milliseconds: 400);
const Curve _kScrollCurve = Curves.fastOutSlowIn;

// This app's contents start out at _kHeadingMaxHeight and they function like
// an appbar. Initially the appbar occupies most of the screen and its section
// headings are laid out in a column. By the time its height has been
// reduced to _kAppBarMidHeight, its layout is horizontal, only one section
// heading is visible, and the section's list of details is visible below the
// heading. The appbar's height can be reduced to no more than _kAppBarMinHeight.
/*
Содержимое этого приложения начинается с _kHeadingMaxHeight, и они функционируют
 как панель приложений. Первоначально панель приложения занимает большую часть
 экрана, а заголовки разделов расположены в столбце. К тому времени, когда его
 высота была уменьшена до _kAppBarMidHeight, ее макет горизонтальный, только
 заголовок только одного раздела отображается, и список деталей раздела
 отображается ниже заголовка. Высота приложения может быть уменьшена не более,
 чем _kAppBarMinHeight.
 */
const double _kAppBarMinHeight = 90.0;
const double _kAppBarMidHeight = 256.0;
// The AppBar's max height depends on the screen, see _AnimationHomeState._buildBody()

// Initially occupies the same space as the status bar and gets smaller as
// the primary scrollable scrolls upwards.
//Изначально занимает то же пространство, что и строка состояния, и становится
// меньше, поскольку первичные прокручиваемые свитки вверх.
// TODO(hansmuller): it would be worth adding something like this to the framework.
class _RenderStatusBarPaddingSliver extends RenderSliver {
  _RenderStatusBarPaddingSliver({
    @required double maxHeight,
    @required double scrollFactor,
  })  : assert(maxHeight != null && maxHeight >= 0.0),
        assert(scrollFactor != null && scrollFactor >= 1.0),
        _maxHeight = maxHeight,
        _scrollFactor = scrollFactor;

  // The height of the status bar
  double get maxHeight => _maxHeight;
  double _maxHeight;

  set maxHeight(double value) {
    assert(maxHeight != null && maxHeight >= 0.0);
    if (_maxHeight == value) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  // That rate at which this renderer's height shrinks when the scroll
  // offset changes.
//  Эта скорость, при которой высота этого визуализатора уменьшается при
// изменении сдвига прокрутки.
  double get scrollFactor => _scrollFactor;
  double _scrollFactor;

  set scrollFactor(double value) {
    assert(scrollFactor != null && scrollFactor >= 1.0);
    if (_scrollFactor == value) return;
    _scrollFactor = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final double height = (maxHeight - constraints.scrollOffset / scrollFactor)
        .clamp(0.0, maxHeight);
    geometry = SliverGeometry(
      paintExtent: math.min(height, constraints.remainingPaintExtent),
      scrollExtent: maxHeight,
      maxPaintExtent: maxHeight,
    );
  }
}

class _StatusBarPaddingSliver extends SingleChildRenderObjectWidget {
  const _StatusBarPaddingSliver({
    Key key,
    @required this.maxHeight,
    this.scrollFactor = 5.0,
  })  : assert(maxHeight != null && maxHeight >= 0.0),
        assert(scrollFactor != null && scrollFactor >= 1.0),
        super(key: key);

  final double maxHeight;
  final double scrollFactor;

  @override
  _RenderStatusBarPaddingSliver createRenderObject(BuildContext context) {
    return _RenderStatusBarPaddingSliver(
      maxHeight: maxHeight,
      scrollFactor: scrollFactor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderStatusBarPaddingSliver renderObject) {
    renderObject
      ..maxHeight = maxHeight
      ..scrollFactor = scrollFactor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DoubleProperty('maxHeight', maxHeight));
    description.add(DoubleProperty('scrollFactor', scrollFactor));
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    @required this.minHeight,
    @required this.maxHeight,
    @required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }

  @override
  String toString() => '_SliverAppBarDelegate';
}

// Arrange the section titles, indicators, and cards. The cards are only included when
// the layout is transitioning between vertical and horizontal. Once the layout is
// horizontal the cards are laid out by a PageView.
//
// The layout of the section cards, titles, and indicators is defined by the
// two 0.0-1.0 "t" parameters, both of which are based on the layout's height:
// - tColumnToRow
//   0.0 when height is maxHeight and the layout is a column
//   1.0 when the height is midHeight and the layout is a row
// - tCollapsed
//   0.0 when height is midHeight and the layout is a row
//   1.0 when height is minHeight and the layout is a (still) row
//
// minHeight < midHeight < maxHeight
//
// The general approach here is to compute the column layout and row size
// and position of each element and then interpolate between them using
// tColumnToRow. Once tColumnToRow reaches 1.0, the layout changes are
// defined by tCollapsed. As tCollapsed increases the titles spread out
// until only one title is visible and the indicators cluster together
// until they're all visible.
/*
Расположите заголовки, индикаторы и карточки раздела. Карты включаются только
тогда, когда макет перемещается между вертикальным и горизонтальным. После
горизонтальной компоновки карты выкладываются с помощью PageView.
Расположение разделяющих карт, заголовков и индикаторов определяется двумя
параметрами 0.0-1.0 "t", оба из которых основаны на высоте макета:
- tColumnToRow
   0.0, когда высота maxHeight и макет - столбец
   1.0, когда высота - средняя высота, а макет - строка
 - tCollapsed
   0.0, когда высота - средняя высота, а макет - строка
   1.0, когда высота равна minHeight, а макет - (неподвижная) строка

 minHeight <midHeight <maxHeight

Общий подход здесь заключается в вычислении макета столбца и размера строки и
позиции каждого элемента, а затем интерполирования между ними с помощью
tColumnToRow. Как только tColumnToRow достигает 1.0, изменения макета
определяются tCollapsed. По мере того, как tCollapsed увеличивает титры,
распространяется только до тех пор, пока не будет видно только одно название,
а индикаторы будут сгруппированы вместе, пока они не станут видимыми.
 */
class _AllSectionsLayout extends MultiChildLayoutDelegate {
  _AllSectionsLayout({
    this.translation,
    this.tColumnToRow,
    this.tCollapsed,
    this.cardCount,
    this.selectedIndex,
  });

  final Alignment translation;
  final double tColumnToRow;
  final double tCollapsed;
  final int cardCount;
  final double selectedIndex;

  Rect _interpolateRect(Rect begin, Rect end) {
    return Rect.lerp(begin, end, tColumnToRow);
  }

  Offset _interpolatePoint(Offset begin, Offset end) {
    return Offset.lerp(begin, end, tColumnToRow);
  }

  @override
  void performLayout(Size size) {
    final double columnCardX = size.width / 5.0;
    final double columnCardWidth = size.width - columnCardX;
    final double columnCardHeight = size.height / cardCount;
    final double rowCardWidth = size.width;
    final Offset offset = translation.alongSize(size);
    double columnCardY = 0.0;
    double rowCardX = -(selectedIndex * rowCardWidth);

    // When tCollapsed > 0 the titles spread apart
    // Когда tCollapsed> 0, названия разделены
    final double columnTitleX = size.width / 10.0;
    final double rowTitleWidth = size.width * ((1 + tCollapsed) / 2.25);
    double rowTitleX =
        (size.width - rowTitleWidth) / 2.0 - selectedIndex * rowTitleWidth;

    // When tCollapsed > 0, the indicators move closer together
    //final double rowIndicatorWidth = 48.0 + (1.0 - tCollapsed) * (rowTitleWidth - 48.0);
    const double paddedSectionIndicatorWidth = kSectionIndicatorWidth + 8.0;
    final double rowIndicatorWidth = paddedSectionIndicatorWidth +
        (1.0 - tCollapsed) * (rowTitleWidth - paddedSectionIndicatorWidth);
    double rowIndicatorX = (size.width - rowIndicatorWidth) / 2.0 -
        selectedIndex * rowIndicatorWidth;

    // Compute the size and origin of each card, title, and indicator for the maxHeight
    // "column" layout, and the midHeight "row" layout. The actual layout is just the
    // interpolated value between the column and row layouts for t.
    /*
    Вычислите размер и происхождение каждой карты, заголовка и индикатора для
    макета maxHeight «столбец» и макета «строка» midHeight. Фактический макет -
    это всего лишь интерполированное значение между макетами столбцов и строк для t.
     */
    for (int index = 0; index < cardCount; index++) {
      // Layout the card for index.
      final Rect columnCardRect = Rect.fromLTWH(
          columnCardX, columnCardY, columnCardWidth, columnCardHeight);
      final Rect rowCardRect =
          Rect.fromLTWH(rowCardX, 0.0, rowCardWidth, size.height);
      final Rect cardRect =
          _interpolateRect(columnCardRect, rowCardRect).shift(offset);
      final String cardId = 'card$index';
      if (hasChild(cardId)) {
        layoutChild(cardId, BoxConstraints.tight(cardRect.size));
        positionChild(cardId, cardRect.topLeft);
      }

      // Layout the title for index.
      final Size titleSize =
          layoutChild('title$index', BoxConstraints.loose(cardRect.size));
      final double columnTitleY =
          columnCardRect.centerLeft.dy - titleSize.height / 2.0;
      final double rowTitleY =
          rowCardRect.centerLeft.dy - titleSize.height / 2.0;
      final double centeredRowTitleX =
          rowTitleX + (rowTitleWidth - titleSize.width) / 2.0;
      final Offset columnTitleOrigin = Offset(columnTitleX, columnTitleY);
      final Offset rowTitleOrigin = Offset(centeredRowTitleX, rowTitleY);
      final Offset titleOrigin =
          _interpolatePoint(columnTitleOrigin, rowTitleOrigin);
      positionChild('title$index', titleOrigin + offset);

      // Layout the selection indicator for index.
      final Size indicatorSize =
          layoutChild('indicator$index', BoxConstraints.loose(cardRect.size));
      final double columnIndicatorX =
          cardRect.centerRight.dx - indicatorSize.width - 16.0;
      final double columnIndicatorY =
          cardRect.bottomRight.dy - indicatorSize.height - 16.0;
      final Offset columnIndicatorOrigin =
          Offset(columnIndicatorX, columnIndicatorY);
      final Rect titleRect =
          Rect.fromPoints(titleOrigin, titleSize.bottomRight(titleOrigin));
      final double centeredRowIndicatorX =
          rowIndicatorX + (rowIndicatorWidth - indicatorSize.width) / 2.0;
      final double rowIndicatorY = titleRect.bottomCenter.dy + 16.0;
      final Offset rowIndicatorOrigin =
          Offset(centeredRowIndicatorX, rowIndicatorY);
      final Offset indicatorOrigin =
          _interpolatePoint(columnIndicatorOrigin, rowIndicatorOrigin);
      positionChild('indicator$index', indicatorOrigin + offset);

      columnCardY += columnCardHeight;
      rowCardX += rowCardWidth;
      rowTitleX += rowTitleWidth;
      rowIndicatorX += rowIndicatorWidth;
    }
  }

  @override
  bool shouldRelayout(_AllSectionsLayout oldDelegate) {
    return tColumnToRow != oldDelegate.tColumnToRow ||
        cardCount != oldDelegate.cardCount ||
        selectedIndex != oldDelegate.selectedIndex;
  }
}

class _AllSectionsView extends AnimatedWidget {
  _AllSectionsView({
    Key key,
    this.sectionIndex,
    @required this.sections,
    @required this.selectedIndex,
    this.minHeight,
    this.midHeight,
    this.maxHeight,
    this.sectionCards = const <Widget>[],
  })  : assert(sections != null),
        assert(sectionCards != null),
        assert(sectionCards.length == sections.length),
        assert(sectionIndex >= 0 && sectionIndex < sections.length),
        assert(selectedIndex != null),
        assert(selectedIndex.value >= 0.0 &&
            selectedIndex.value < sections.length.toDouble()),
        super(key: key, listenable: selectedIndex);

  final int sectionIndex;
  final List<Section> sections;
  final ValueNotifier<double> selectedIndex;
  final double minHeight;
  final double midHeight;
  final double maxHeight;
  final List<Widget> sectionCards;

  num _selectedIndexDelta(int index) {
    return (index.toDouble() - selectedIndex.value).abs().clamp(0.0, 1.0);
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final Size size = constraints.biggest;

    // The layout's progress from from a column to a row. Its value is
    // 0.0 when size.height equals the maxHeight, 1.0 when the size.height
    // equals the midHeight.
    // The layout's progress from from a column to a row. Its value is
    // 0.0 when size.height equals the maxHeight, 1.0 when the size.height
    // equals the midHeight.
    /*
    Прогресс макета от столбца к строке. Его значение равно 0.0, когда size.height
     равно maxHeight, 1.0, когда size.height равен midHeight.
Прогресс макета от столбца к строке. Его значение равно 0.0, когда size.height
равно maxHeight, 1.0, когда size.height равен midHeight.
     */
    final double tColumnToRow = 1.0 -
        ((size.height - midHeight) / (maxHeight - midHeight)).clamp(0.0, 1.0);

    // The layout's progress from from the midHeight row layout to
    // a minHeight row layout. Its value is 0.0 when size.height equals
    // midHeight and 1.0 when size.height equals minHeight.
    /*
    Прогресс макета от макета строки среднего уровня до макета строки minHeight.
    Его значение равно 0.0, когда size.height равно midHeight и 1.0, когда
    size.height равно minHeight.
     */
    final double tCollapsed = 1.0 -
        ((size.height - minHeight) / (midHeight - minHeight)).clamp(0.0, 1.0);

    double _indicatorOpacity(int index) {
      return 1.0 - _selectedIndexDelta(index) * 0.5;
    }

    double _titleOpacity(int index) {
      return 1.0 - _selectedIndexDelta(index) * tColumnToRow * 0.5;
    }

    double _titleScale(int index) {
      return 1.0 - _selectedIndexDelta(index) * tColumnToRow * 0.15;
    }

    final List<Widget> children = List<Widget>.from(sectionCards);

    for (int index = 0; index < sections.length; index++) {
      final Section section = sections[index];
      children.add(LayoutId(
        id: 'title$index',
        child: SectionTitle(
          section: section,
          scale: _titleScale(index),
          opacity: _titleOpacity(index),
        ),
      ));
    }

    for (int index = 0; index < sections.length; index++) {
      children.add(LayoutId(
        id: 'indicator$index',
        child: SectionIndicator(
          opacity: _indicatorOpacity(index),
        ),
      ));
    }

    return CustomMultiChildLayout(
      delegate: _AllSectionsLayout(
        translation:
            Alignment((selectedIndex.value - sectionIndex) * 2.0 - 1.0, -1.0),
        tColumnToRow: tColumnToRow,
        tCollapsed: tCollapsed,
        cardCount: sections.length,
        selectedIndex: selectedIndex.value,
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _build);
  }
}

// Support snapping scrolls to the midScrollOffset: the point at which the
// app bar's height is _kAppBarMidHeight and only one section heading is
// visible.
/*
Поддержка привязки прокрутки к midScrollOffset: точка, в которой высота панели
приложения - _kAppBarMidHeight, и только один заголовок раздела.
 */
class _SnappingScrollPhysics extends ClampingScrollPhysics {
  const _SnappingScrollPhysics({
    ScrollPhysics parent,
    @required this.midScrollOffset,
  })  : assert(midScrollOffset != null),
        super(parent: parent);

  final double midScrollOffset;

  @override
  _SnappingScrollPhysics applyTo(ScrollPhysics ancestor) {
    return _SnappingScrollPhysics(
        parent: buildParent(ancestor), midScrollOffset: midScrollOffset);
  }

  Simulation _toMidScrollOffsetSimulation(double offset, double dragVelocity) {
    final double velocity = math.max(dragVelocity, minFlingVelocity);
    return ScrollSpringSimulation(spring, offset, midScrollOffset, velocity,
        tolerance: tolerance);
  }

  Simulation _toZeroScrollOffsetSimulation(double offset, double dragVelocity) {
    final double velocity = math.max(dragVelocity, minFlingVelocity);
    return ScrollSpringSimulation(spring, offset, 0.0, velocity,
        tolerance: tolerance);
  }

  @override
  Simulation createBallisticSimulation(
      ScrollMetrics position, double dragVelocity) {
    final Simulation simulation =
        super.createBallisticSimulation(position, dragVelocity);
    final double offset = position.pixels;

    if (simulation != null) {
      // The drag ended with sufficient velocity to trigger creating a simulation.
      // If the simulation is headed up towards midScrollOffset but will not reach it,
      // then snap it there. Similarly if the simulation is headed down past
      // midScrollOffset but will not reach zero, then snap it to zero.
      /*
      // Прерывание закончилось достаточной скоростью, чтобы вызвать создание
      симуляции. Если симуляция направлена вверх к midScrollOffset, но не дойдет
      до нее, тогда привяжите ее там. Аналогично, если симуляция направлена вниз
      по серединеScrollOffset, но не достигнет нуля, тогда привяжите ее к нулю.
       */
      final double simulationEnd = simulation.x(double.infinity);
      if (simulationEnd >= midScrollOffset) return simulation;
      if (dragVelocity > 0.0)
        return _toMidScrollOffsetSimulation(offset, dragVelocity);
      if (dragVelocity < 0.0)
        return _toZeroScrollOffsetSimulation(offset, dragVelocity);
    } else {
      // The user ended the drag with little or no velocity. If they
      // didn't leave the offset above midScrollOffset, then
      // snap to midScrollOffset if they're more than halfway there,
      // otherwise snap to zero.
      /*
      Пользователь закончил перетаскивание с небольшой скоростью или без нее.
      Если они не оставили смещение выше midScrollOffset, тогда привязайте к
      midScrollOffset, если они больше, чем на полпути, иначе привязка к нулю.
       */
      final double snapThreshold = midScrollOffset / 2.0;
      if (offset >= snapThreshold && offset < midScrollOffset)
        return _toMidScrollOffsetSimulation(offset, dragVelocity);
      if (offset > 0.0 && offset < snapThreshold)
        return _toZeroScrollOffsetSimulation(offset, dragVelocity);
    }
    return simulation;
  }
}

class AnimationHome extends StatefulWidget {
  const AnimationHome({Key key}) : super(key: key);

  static const String routeName = '/animation';

  @override
  _AnimationHomeState createState() => _AnimationHomeState();
}

class _AnimationHomeState extends State<AnimationHome> {
  final ScrollController _scrollController = ScrollController();
  final PageController _headingPageController = PageController();
  final PageController _detailsPageController = PageController();
  ScrollPhysics _headingScrollPhysics = const NeverScrollableScrollPhysics();
  ValueNotifier<double> selectedIndex = ValueNotifier<double>(0.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kAppBackgroundColor,
      body: Builder(
        // Insert an element so that _buildBody can find the PrimaryScrollController.
        //Вставьте элемент так, чтобы _buildBody мог найти основной ScrollController.
        builder: _buildBody,
      ),
    );
  }

/*
  void _handleBackButton(double midScrollOffset) {
    if (_scrollController.offset >= midScrollOffset)
      _scrollController.animateTo(0.0, curve: _kScrollCurve, duration: _kScrollDuration);
    else
      Navigator.maybePop(context);
  }
*/

  // Only enable paging for the heading when the user has scrolled to midScrollOffset.
  // Paging is enabled/disabled by setting the heading's PageView scroll physics.
  // Включить только пейджинг для заголовка, когда пользователь прокрутил до середины экрана.
  // Пейджинг включен / отключен, установив физику прокрутки заголовка заголовка.
  bool _handleScrollNotification(
      ScrollNotification notification, double midScrollOffset) {
    if (notification.depth == 0 && notification is ScrollUpdateNotification) {
      final ScrollPhysics physics =
          _scrollController.position.pixels >= midScrollOffset
              ? const PageScrollPhysics()
              : const NeverScrollableScrollPhysics();
      if (physics != _headingScrollPhysics) {
        setState(() {
          _headingScrollPhysics = physics;
        });
      }
    }
    return false;
  }

  void _maybeScroll(double midScrollOffset, int pageIndex, double xOffset) {
    if (_scrollController.offset < midScrollOffset) {
      // Scroll the overall list to the point where only one section card shows.
      //Прокрутите общий список до точки, где отображается только одна секционная карта.
      // At the same time scroll the PageViews to the page at pageIndex.
      //В то же время прокрутите страницу PageViews на страницу на страницеIndex.
      _headingPageController.animateToPage(pageIndex,
          curve: _kScrollCurve, duration: _kScrollDuration);
      _scrollController.animateTo(midScrollOffset,
          curve: _kScrollCurve, duration: _kScrollDuration);
    } else {
      // One one section card is showing: scroll one page forward or back.
      //Отображается одна карта раздела: прокрутка одной страницы вперед или назад.
      final double centerX =
          _headingPageController.position.viewportDimension / 2.0;
      final int newPageIndex =
          xOffset > centerX ? pageIndex + 1 : pageIndex - 1;
      _headingPageController.animateToPage(newPageIndex,
          curve: _kScrollCurve, duration: _kScrollDuration);
    }
  }

  bool _handlePageNotification(ScrollNotification notification,
      PageController leader, PageController follower) {
    if (notification.depth == 0 && notification is ScrollUpdateNotification) {
      selectedIndex.value = leader.page;
      if (follower.page != leader.page)
        // ignore: deprecated_member_use
        follower.position.jumpToWithoutSettling(
            leader.position.pixels); // ignore: deprecated_member_use
    }
    return false;
  }

  Iterable<Widget> _detailItemsFor(Section section) {
    final Iterable<Widget> detailItems =
        section.details.map((Product product) {
      return SectionDetailView(detail: product);
    });
    return detailItems;
  }

  Iterable<Widget> _allHeadingItems(double maxHeight, double midScrollOffset) {
    final List<Widget> sectionCards = <Widget>[];
    for (int index = 0; index < allSections.length; index++) {
      sectionCards.add(LayoutId(
        id: 'card$index',
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: SectionCard(section: allSections[index]),
            onTapUp: (TapUpDetails details) {
              final double xOffset = details.globalPosition.dx;
              setState(() {
                _maybeScroll(midScrollOffset, index, xOffset);
              });
            }),
      ));
    }

    final List<Widget> headings = <Widget>[];
    for (int index = 0; index < allSections.length; index++) {
      headings.add(Container(
        color: _kAppBackgroundColor,
        child: ClipRect(
          child: _AllSectionsView(
            sectionIndex: index,
            sections: allSections,
            selectedIndex: selectedIndex,
            minHeight: _kAppBarMinHeight,
            midHeight: _kAppBarMidHeight,
            maxHeight: maxHeight,
            sectionCards: sectionCards,
          ),
        ),
      ));
    }
    return headings;
  }

  Widget _buildBody(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    final double statusBarHeight = mediaQueryData.padding.top;
    final double screenHeight = mediaQueryData.size.height;
    final double appBarMaxHeight = screenHeight - statusBarHeight;

    // The scroll offset that reveals the appBarMidHeight appbar.
    //Смещение прокрутки, которое показывает панель приложений appBarMidHeight.
    final double appBarMidScrollOffset =
        statusBarHeight + appBarMaxHeight - _kAppBarMidHeight;

    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              return _handleScrollNotification(
                  notification, appBarMidScrollOffset);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: _SnappingScrollPhysics(
                  midScrollOffset: appBarMidScrollOffset),
              slivers: <Widget>[
                // Start out below the status bar, gradually move to the top of the screen.
                //Начните с строки состояния, постепенно переходите в верхнюю часть экрана.
                _StatusBarPaddingSliver(
                  maxHeight: statusBarHeight,
                  scrollFactor: 7.0,
                ),
                // Section Headings
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    minHeight: _kAppBarMinHeight,
                    maxHeight: appBarMaxHeight,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        return _handlePageNotification(notification,
                            _headingPageController, _detailsPageController);
                      },
                      child: PageView(
                        physics: _headingScrollPhysics,
                        controller: _headingPageController,
                        // ignore: argument_type_not_assignable
                        children: _allHeadingItems(
                            appBarMaxHeight, appBarMidScrollOffset),
                      ),
                    ),
                  ),
                ),
                // Details
                SliverToBoxAdapter(
                  child: SizedBox(
                    //TODO сделать вычисляемый размер
                    height: 1400.0,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        return _handlePageNotification(notification,
                            _detailsPageController, _headingPageController);
                      },
                      child: PageView(
                        controller: _detailsPageController,
                        children: allSections.map((Section section) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _detailItemsFor(section).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
/*
          Positioned(
            top: statusBarHeight,
            left: 0.0,
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: SafeArea(
                top: false,
                bottom: false,
                child: IconButton(
                    icon: const BackButtonIcon(),
                    tooltip: 'Back',
                    onPressed: () {
                      _handleBackButton(appBarMidScrollOffset);
                    }
                ),
              ),
            ),
          ),
*/
        ],
      ),
    );
  }
}
