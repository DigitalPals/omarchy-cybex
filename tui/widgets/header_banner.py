"""ASCII art header banner widget"""

from textual.widgets import Static


def preserve_spaces(text: str) -> str:
    """Replace regular spaces with non-breaking spaces to preserve alignment."""
    return text.replace(" ", "\u00a0")


ASCII_ART = preserve_spaces("""\
                     $$a.
                      `$$$
 .a&$$$&a, a$$a..a$$a. `$$bd$$$&a,    .a&$""$&a     .a$$a..a$$a.
d#7^' `^^' `Q$$bd$$$^   1$#7^' `^Q$, d#7@Qbd@'' d$   Q$$$$$$$$P
Y$b,. .,,.    Q$$$$'   .$$$b.. .,d7' Q$&a,..,a&$P'  .d$$$PQ$$$b
 `@Q$$$P@'    d$$$'    `^@Q$$$$$@"'   `^@Q$$$P@^'   @Q$P@  @Q$P@
              @$$P""")

TITLE = preserve_spaces("                      C Y B E X   I N S T A L L E R")


class HeaderBanner(Static):
    """ASCII art header banner for the installer"""

    def __init__(self) -> None:
        super().__init__(id="header-banner")

    def on_mount(self) -> None:
        content = f"[#cba6f7]{ASCII_ART}[/#cba6f7]\n\n[bold #f5c2e7]{TITLE}[/bold #f5c2e7]"
        self.update(content)
