/// The three photos MangGrade needs for one mango, in capture order.
///
/// The order of [MangoView.values] is the order the Scan screen asks for
/// the photos: front first, then back, then top.
enum MangoView {
  front,
  back,
  top,
}

extension MangoViewInfo on MangoView {
  /// Short name shown on buttons and slot tiles.
  String get label => switch (this) {
        MangoView.front => 'Front',
        MangoView.back => 'Back',
        MangoView.top => 'Top',
      };

  /// What the user should do for this photo.
  String get instruction => switch (this) {
        MangoView.front =>
          'Lay the mango on its side and photograph the front face.',
        MangoView.back =>
          'Turn the mango over and photograph the opposite face.',
        MangoView.top =>
          'Photograph the mango from above, showing the stem end.',
      };

  /// Multipart field name expected by the backend (/predict-multiview).
  /// Must match the parameter names in main.py: front, back, top.
  String get apiField => name;
}
