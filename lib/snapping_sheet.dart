library snapping_sheet;

import 'package:flutter/widgets.dart';

/// A snapping position that tells how a [SnappingSheet] snapps to different positions
class SnapPosition {
  /// The snapping position in pixels
  /// [positionFactor] should be null if this is used.
  final double positionPixel;

  /// The snapping position in relation of the
  /// available height. [positionPixel] should be null if this is used.
  final double positionFactor;

  /// The animation curve to this snapping position
  final Curve snappingCurve;

  /// The snapping duration
  final Duration snappingDuration;

  const SnapPosition(
      {this.positionFactor,
      this.positionPixel,
      this.snappingCurve = Curves.easeOutExpo,
      this.snappingDuration = const Duration(milliseconds: 500)});

  /// Getting the position in pixels
  double _getPositionInPixels(double height) {
    if (positionPixel != null) {
      return positionPixel;
    }
    return height * positionFactor;
  }
}

/// A sheet that snaps to different positions
class SnappingSheet extends StatefulWidget {
  /// The widget behind the [sheet] widget. It has a constant height
  /// and do not change when the sheet is draged up or down.
  final Widget child;

  /// The sheet of
  final Widget sheet;

  /// The remaining space between the the top of the [sheet] and the
  /// rest of the space above. It resized every time the sheet is draged
  final Widget remaining;

  /// The widget for grabing the [sheet]. It placed above the [sheet]
  /// widget.
  final Widget grabing;

  /// The height of the grabing widget
  final double grabingHeight;

  /// The different snapping positions for the [sheet]
  final List<SnapPosition> snapPositions;

  /// The init snap position. If this position is not included in [snapPositions]
  /// it can not be snapped back after the [sheet] is leaving this position.
  final SnapPosition initSnapPosition;

  /// The margin of the remaining space. Can be negative.
  final EdgeInsets remainingMargin;

  /// The controller for the [SnappingSheet]
  final SnapSheetController snapSheetController;

  /// Is called when the [sheet] is being moved
  final Function(double pixelPosition) onMove;

  final VoidCallback onSnapBegin;

  /// Is called when the [sheet] is snappet to one of the [snapPositions]
  final VoidCallback onSnapEnd;

  const SnappingSheet({
    Key key,
    @required this.child,
    @required this.sheet,
    this.grabing,
    this.grabingHeight = 75.0,
    this.snapPositions = const [
      SnapPosition(positionPixel: 0.0),
      SnapPosition(positionFactor: 0.5),
      SnapPosition(positionFactor: 0.9),
    ],
    this.initSnapPosition,
    this.remaining,
    this.remainingMargin = const EdgeInsets.all(0.0),
    this.snapSheetController,
    this.onMove,
    this.onSnapBegin,
    this.onSnapEnd,
  }) : super(key: key);

  @override
  _SnappingSheetState createState() => _SnappingSheetState();
}

class _SnappingSheetState extends State<SnappingSheet>
    with SingleTickerProviderStateMixin {
  /// How heigh up the sheet is dragged in pixels
  double _currentDragAmount;

  /// The controller for the snapping animation
  AnimationController _snappingAnimationController;

  /// The snapping animation
  Animation<double> _snappingAnimation;

  /// Last constrains of SnapSheet
  BoxConstraints _currentConstraints;

  /// Last snapping location
  SnapPosition _lastSnappingLocation;

  /// The init snap position for the sheet
  SnapPosition _initSnapPosition;

  @override
  void initState() {
    super.initState();

    // Set the init snap position
    _initSnapPosition = widget.initSnapPosition ?? widget.snapPositions.first;

    // Create the snapping controller
    _snappingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 750),
    );

    // Listen when the snapping begin
    _snappingAnimationController.addListener(() {
      setState(() {
        _currentDragAmount = _snappingAnimation.value;
      });
      if (widget.onMove != null) {
        widget.onMove(_currentDragAmount);
      }
      if (widget.onSnapEnd != null &&
          _snappingAnimationController.isCompleted) {
        widget.onSnapEnd();
      }
    });

    // Connect the given listeners
    widget.snapSheetController?._addListeners(_snapToPosition);
    widget.snapSheetController?.snapPositions = widget.snapPositions;
  }

  @override
  void didUpdateWidget(SnappingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.snapSheetController?.snapPositions = widget.snapPositions;
  }

  /// Get the closest snapping location
  SnapPosition _getClosestSnapPosition() {
    // Set the init for comparing values.
    double minDistance;
    SnapPosition closestSnapPosition;

    // Find the closest snapping position
    for (var snapPosition in widget.snapPositions) {
      // Getting the distance to the current snapPosition
      var snappingDistance =
          (snapPosition._getPositionInPixels(_currentConstraints.maxHeight) -
                  _currentDragAmount)
              .abs();

      // It should be hard to snap to the last snapping location.
      var snappingFactor = snapPosition == _lastSnappingLocation ? 0.1 : 1;

      // Check if this snapPosition has the minimum distance
      if (minDistance == null ||
          minDistance > snappingDistance / snappingFactor) {
        minDistance = snappingDistance / snappingFactor;
        closestSnapPosition = snapPosition;
      }
    }

    return closestSnapPosition;
  }

  /// Animates the the closest stop
  void _animateToClosestStop() {
    // Get the closest snapping location
    var closestSnapPosition = _getClosestSnapPosition();
    _snapToPosition(closestSnapPosition);
  }

  /// Snaps to a given [SnapPosition]
  void _snapToPosition(SnapPosition snapPosition) {
    // Update the info about the last snapping location
    _lastSnappingLocation = snapPosition;
    widget.snapSheetController?.currentSnapPosition = snapPosition;

    // Create a new cureved animation between the current drag amount and the snapping
    // location
    _snappingAnimation = Tween<double>(
            begin: _currentDragAmount,
            end: _getSnapPositionInPixels(snapPosition))
        .animate(CurvedAnimation(
      curve: snapPosition.snappingCurve,
      parent: _snappingAnimationController,
    ));

    // Reset and start animation
    _snappingAnimationController.duration = snapPosition.snappingDuration;
    _snappingAnimationController.reset();
    _snappingAnimationController.forward();

    if (widget.onSnapBegin != null) {
      widget.onSnapBegin();
    }
  }

  /// Getting the snap position in pixels
  double _getSnapPositionInPixels(SnapPosition snapPosition) {
    return snapPosition._getPositionInPixels(
        _currentConstraints.maxHeight - widget.grabingHeight);
  }

  Widget _buildRemaining() {
    if (widget.remaining == null) {
      return SizedBox();
    }

    return Positioned(
        top: widget.remainingMargin.top,
        bottom: _currentDragAmount +
            widget.remainingMargin.bottom +
            widget.grabingHeight,
        left: widget.remainingMargin.left,
        right: widget.remainingMargin.right,
        child: widget.remaining);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _currentConstraints = constraints;
      if (_currentDragAmount == null) {
        _currentDragAmount = _getSnapPositionInPixels(_initSnapPosition);
      }

      return Stack(fit: StackFit.expand, children: <Widget>[
        // The widget behind the sheet
        Positioned.fill(
          child: widget.child,
        ),

        // The widget of the remaining space
        _buildRemaining(),

        // The grabing area
        Positioned(
          left: 0,
          right: 0,
          height: widget.grabingHeight,
          bottom: _currentDragAmount,
          child: GestureDetector(
            child: widget.grabing,
            onVerticalDragEnd: (_) {
              _animateToClosestStop();
            },
            onVerticalDragStart: (_) {
              // Stop the current snapping animation so the user is
              // able to drag again.
              _snappingAnimationController.stop();
            },
            onVerticalDragUpdate: (dragEvent) {
              setState(() {
                _currentDragAmount -= dragEvent.delta.dy;
              });
              if (widget.onMove != null) {
                widget.onMove(_currentDragAmount);
              }
            },
          ),
        ),

        // The sheet
        Positioned(
            top: constraints.maxHeight - _currentDragAmount,
            left: 0,
            right: 0,
            bottom: 0,
            child: widget.sheet)
      ]);
    });
  }
}

/// Controlls the [SnappingSheet] widget
class SnapSheetController {
  Function(SnapPosition value) _setSnapSheetPositionListener;

  /// The different snap positions the [SnappingSheet] currently has.
  List<SnapPosition> snapPositions;

  /// The current snap positions of the [SnappingSheet].
  SnapPosition currentSnapPosition;

  void _addListeners(
      Function(SnapPosition value) setSnapSheetPositionListener) {
    this._setSnapSheetPositionListener = setSnapSheetPositionListener;
  }

  /// Snaps to a given [SnapPosition]
  void snapToPosition(SnapPosition snapPosition) {
    _setSnapSheetPositionListener(snapPosition);
  }
}