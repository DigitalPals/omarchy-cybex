//! Catppuccin Mocha theme colors

use ratatui::style::Color;

/// Catppuccin Mocha color palette
pub struct CatppuccinMocha {
    pub rosewater: Color,
    pub flamingo: Color,
    pub pink: Color,
    pub mauve: Color,
    pub red: Color,
    pub maroon: Color,
    pub peach: Color,
    pub yellow: Color,
    pub green: Color,
    pub teal: Color,
    pub sky: Color,
    pub sapphire: Color,
    pub blue: Color,
    pub lavender: Color,
    pub text: Color,
    pub subtext1: Color,
    pub subtext0: Color,
    pub overlay2: Color,
    pub overlay1: Color,
    pub overlay0: Color,
    pub surface2: Color,
    pub surface1: Color,
    pub surface0: Color,
    pub base: Color,
    pub mantle: Color,
    pub crust: Color,
}

/// Catppuccin Mocha theme instance
pub const THEME: CatppuccinMocha = CatppuccinMocha {
    rosewater: Color::Rgb(245, 224, 220), // #f5e0dc
    flamingo: Color::Rgb(242, 205, 205),  // #f2cdcd
    pink: Color::Rgb(245, 194, 231),      // #f5c2e7
    mauve: Color::Rgb(203, 166, 247),     // #cba6f7
    red: Color::Rgb(243, 139, 168),       // #f38ba8
    maroon: Color::Rgb(235, 160, 172),    // #eba0ac
    peach: Color::Rgb(250, 179, 135),     // #fab387
    yellow: Color::Rgb(249, 226, 175),    // #f9e2af
    green: Color::Rgb(166, 227, 161),     // #a6e3a1
    teal: Color::Rgb(148, 226, 213),      // #94e2d5
    sky: Color::Rgb(137, 220, 235),       // #89dceb
    sapphire: Color::Rgb(116, 199, 236),  // #74c7ec
    blue: Color::Rgb(137, 180, 250),      // #89b4fa
    lavender: Color::Rgb(180, 190, 254),  // #b4befe
    text: Color::Rgb(205, 214, 244),      // #cdd6f4
    subtext1: Color::Rgb(186, 194, 222),  // #bac2de
    subtext0: Color::Rgb(166, 173, 200),  // #a6adc8
    overlay2: Color::Rgb(147, 153, 178),  // #9399b2
    overlay1: Color::Rgb(127, 132, 156),  // #7f849c
    overlay0: Color::Rgb(108, 112, 134),  // #6c7086
    surface2: Color::Rgb(88, 91, 112),    // #585b70
    surface1: Color::Rgb(69, 71, 90),     // #45475a
    surface0: Color::Rgb(49, 50, 68),     // #313244
    base: Color::Rgb(30, 30, 46),         // #1e1e2e
    mantle: Color::Rgb(24, 24, 37),       // #181825
    crust: Color::Rgb(17, 17, 27),        // #11111b
};
