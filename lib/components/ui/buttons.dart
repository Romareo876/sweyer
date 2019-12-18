/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/


import 'package:flutter/material.dart';
import 'package:flutter_music_player/flutter_music_player.dart';
import 'package:flutter_music_player/constants.dart' as Constants;

/// Button to go back from page
class CustomBackButton extends StatelessWidget {
  const CustomBackButton({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomIconButton(
      icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
      splashColor: Constants.AppTheme.splash.auto(context),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

/// Creates `Raised` with border radius, by default colored into main app color - `Colors.deepPurple`
class PrimaryRaisedButton extends RaisedButton {
  PrimaryRaisedButton(
      {Key key,
      @required Function onPressed,

      /// Text to show inside button
      @required String text,

      /// Loading shows loading inside button
      bool loading = false,

      /// Style applied to text
      TextStyle textStyle = const TextStyle(color: Colors.white),
      Color color = Colors.deepPurple,
      double borderRadius = 15.0})
      : super(
          key: key,
          child: loading
              ? SizedBox(
                  width: 25.0,
                  height: 25.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(text, style: textStyle),
          color: color,
          onPressed: onPressed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
}

/// Creates `FlatButton` with border radius, perfect for `showDialog`s accept and decline buttons
class DialogFlatButton extends FlatButton {
  DialogFlatButton(
      {Key key,
      @required Widget child,
      @required Function onPressed,
      Color textColor,
      double borderRadius = 5.0})
      : super(
          key: key,
          child: child,
          onPressed: onPressed,
          textColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(borderRadius),
            ),
          ),
        );
}