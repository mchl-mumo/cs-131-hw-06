import sys
import time

# PROVIDED: DO NOT EDIT.
# A mock NextDraw plotter that draws a preview instead of moving a real pen.
#   * By default it opens a window and animates the drawing.
#   * `--nowindow` skips the window, so `--nowindow --out x.png` just saves an
#     image (this is what py2png and piq2png do).
#   * In the image, pen-down moves are blue and pen-up moves are pink; a
#     pen_down() immediately followed by pen_up() is drawn as a dot.
#   * The runtime's safe area (1 inch inside the paper's edges) is a grey
#     dashed box; any move outside it is red.
#
# The mock tracks the pen's position and up/down state itself, so it works
# without a window.

# Travel dimensions (inches) per NextDraw model index. Only model 9 (the
# NextDraw 1117 used by the course) has been checked against real hardware;
# other models fall back to its dimensions with a warning.
MODEL_TRAVEL_INCHES = {
    9: (16.93, 11.69),  # NextDraw 1117
}
DEFAULT_TRAVEL = MODEL_TRAVEL_INCHES[9]

MODEL_NAMES = {
    8: "NextDraw 8511",
    9: "NextDraw 1117",
    10: "NextDraw 2234",
}

SHOW_WINDOW = "--nowindow" not in sys.argv[1:]


class Options:
    def __init__(self):
        self.model = 9


class Params:
    def __init__(self):
        self.model_name = None


class NextDraw:
    def __init__(self, draw_delay=0.02):
        self.options = Options()
        self.params = Params()
        self.draw_delay = draw_delay
        self.interactive_mode = False
        self.screen = None
        self.pen = None
        self.bounds = None
        self.x, self.y = 0.0, 0.0      # where the pen actually is (unclipped)
        self.pen_is_down = False
        self.moved_since_pendown = False
        self.physical_position = (0.0, 0.0)
        self.segments = []  # (x0, y0, x1, y1, pen_down) for every move, for export()
        self.dots = []      # (x, y) for every pen-down/pen-up without movement
        # The safe area (left, top, right, bottom), in inches, set by the
        # runtime; moves outside it, between begin_drawing() and
        # end_drawing(), are drawn in red.
        self.safe_area = None
        self.drawing_segments = (0, None)   # [first, last) segment index of the drawing
        self.drawing_dots = (0, None)

    def interactive(self):
        self.interactive_mode = True

    def connect(self):
        model = self.options.model
        travel_x, travel_y = MODEL_TRAVEL_INCHES.get(model, DEFAULT_TRAVEL)
        if model not in MODEL_TRAVEL_INCHES:
            print(
                f"[mock_nextdraw] Warning: travel size for model {model} "
                f"isn't verified; using model 9's {DEFAULT_TRAVEL} as a "
                "stand-in. Add a confirmed entry to MODEL_TRAVEL_INCHES if "
                "you have the real numbers."
            )
        self.params.model_name = MODEL_NAMES.get(model, f"Unknown model {model}")
        self.bounds = (0, 0, travel_x, travel_y)

        if SHOW_WINDOW:
            self._open_window(travel_x, travel_y)
        elif not any(flag in sys.argv[1:] for flag in ("--png", "--pdf", "--out")):
            print("[mock_nextdraw] --nowindow without --png/--pdf/--out: nothing will be shown")
        return True

    def _open_window(self, travel_x, travel_y):
        import turtle

        px_per_in = min(1200 / travel_x, 800 / travel_y)
        width = int(travel_x * px_per_in) + 40
        height = int(travel_y * px_per_in) + 40

        self.screen = turtle.Screen()
        self.screen.title(f"NextDraw Mock Preview - {self.params.model_name}")
        self.screen.setup(width=width, height=height)
        # Disable per-move canvas redraws; without this, drawings with many
        # segments (e.g. recursive fractals) can take minutes just repainting
        # the Tk canvas. A single redraw happens in disconnect() instead.
        self.screen.tracer(0, 0)
        # Flip Y so (0, 0) is the top-left corner, matching the plotter's
        # home position, and use inches as world units.
        self.screen.setworldcoordinates(0, travel_y, travel_x, 0)

        border = turtle.Turtle()
        border.hideturtle()
        border.speed(0)
        border.penup()
        border.goto(0, 0)
        border.pendown()
        border.goto(travel_x, 0)
        border.goto(travel_x, travel_y)
        border.goto(0, travel_y)
        border.goto(0, 0)
        border.penup()

        self.pen = turtle.Turtle()
        self.pen.pensize(2)
        self.pen.speed(0)
        self.pen.hideturtle()
        self.pen.penup()

    # Hooks for the runtime's safe-area check (the real NextDraw has none).
    def set_safe_area(self, area):
        self.safe_area = area

    def begin_drawing(self):
        self.drawing_segments = (len(self.segments), None)
        self.drawing_dots = (len(self.dots), None)

    def end_drawing(self):
        self.drawing_segments = (self.drawing_segments[0], len(self.segments))
        self.drawing_dots = (self.drawing_dots[0], len(self.dots))

    def _outside(self, x, y):
        if self.safe_area is None:
            return False
        left, top, right, bottom = self.safe_area
        slack = 1e-6
        return not (left - slack <= x <= right + slack and top - slack <= y <= bottom + slack)

    def disconnect(self):
        if self.screen is not None:
            self.screen.update()
            self.screen.exitonclick()

    def penup(self):
        if self.pen_is_down and not self.moved_since_pendown:
            self.dots.append((self.x, self.y))
            if self.pen is not None:
                self.pen.dot(4)
        self.pen_is_down = False
        if self.pen is not None:
            self.pen.penup()

    def pendown(self):
        self.pen_is_down = True
        self.moved_since_pendown = False
        if self.pen is not None:
            self.pen.pendown()

    def _delay(self):
        if self.draw_delay and self.pen is not None:
            time.sleep(self.draw_delay)

    def _clip_to_bounds(self, x, y):
        xmin, ymin, xmax, ymax = self.bounds
        return (min(max(x, xmin), xmax), min(max(y, ymin), ymax))

    def _move_to(self, x, y):
        self.segments.append((self.x, self.y, x, y, self.pen_is_down))
        self.x, self.y = x, y
        self.moved_since_pendown = True
        if self.pen is not None:
            self.pen.goto(x, y)
        self._delay()

    def current_pos(self):
        return self.physical_position

    def turtle_pos(self):
        return (self.x, self.y)

    # Absolute commands
    def goto(self, x, y):
        self._move_to(x, y)
        self.physical_position = self._clip_to_bounds(x, y)

    def moveto(self, x, y):
        self.penup()
        self._move_to(x, y)
        self.physical_position = self._clip_to_bounds(x, y)

    def lineto(self, x, y):
        self.pendown()
        self._move_to(x, y)
        self.physical_position = self._clip_to_bounds(x, y)

    # Relative commands
    def go(self, dx, dy):
        new_x, new_y = self.x + dx, self.y + dy
        self._move_to(new_x, new_y)
        self.physical_position = self._clip_to_bounds(new_x, new_y)

    def move(self, dx, dy):
        self.penup()
        self.go(dx, dy)

    def line(self, dx, dy):
        self.pendown()
        self.go(dx, dy)

    def export(self, path):
        '''Render recorded segments and dots to PATH (.png or .pdf),
        independent of the live turtle window. Pen-down moves are blue,
        pen-up moves are light pink, matching nextdrawcore's own preview
        color convention. If the runtime set a safe area, it is drawn as a
        grey dashed box, and moves outside it are red.'''
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        xmin, ymin, xmax, ymax = self.bounds
        fig, ax = plt.subplots(figsize=(xmax - xmin, ymax - ymin))
        ax.set_xlim(xmin, xmax)
        ax.set_ylim(ymax, ymin)  # flip Y: origin at top-left, matching the plotter
        ax.set_aspect("equal")
        ax.axis("off")
        ax.add_patch(plt.Rectangle(
            (xmin, ymin), xmax - xmin, ymax - ymin,
            fill=False, edgecolor="black", linewidth=1,
        ))

        if self.safe_area is not None:
            left, top, right, bottom = self.safe_area
            ax.add_patch(plt.Rectangle(
                (left, top), right - left, bottom - top,
                fill=False, edgecolor="grey", linewidth=1.0, linestyle="--",
            ))

        def in_drawing(i, span):
            first, last = span
            return first <= i and (last is None or i < last)

        for i, (x0, y0, x1, y1, pen_down) in enumerate(self.segments):
            # The safe area is a rectangle, so a straight move stays inside
            # it exactly when both of its ends do.
            outside = in_drawing(i, self.drawing_segments) and (
                self._outside(x0, y0) or self._outside(x1, y1))
            if outside:
                ax.plot([x0, x1], [y0, y1], color="red", linewidth=2.2 if pen_down else 1.4)
            elif pen_down:
                ax.plot([x0, x1], [y0, y1], color="blue", linewidth=1.5)
            else:
                ax.plot([x0, x1], [y0, y1], color="lightpink", linewidth=0.7)

        for i, (x, y) in enumerate(self.dots):
            outside = in_drawing(i, self.drawing_dots) and self._outside(x, y)
            ax.plot([x], [y], marker="o", markersize=3, color="red" if outside else "blue")

        fig.tight_layout(pad=0.2)
        fig.savefig(path, dpi=150)
        plt.close(fig)
        print(f"[mock_nextdraw] Saved preview to {path}")
