# ast
Red syntax tree explorer

## Usage: `ast <struct>`

`<struct>` can be block of code (or empty block), file, function, object or map.

Drawing edges can take some time with longer code. Can't switch off `auto-sync?`, because then it will crash.

Try out options on contextual menu while pointing on node.

## Editing graph

Nodes can be added, edited and deleted from menu opened by right-click on mouse.

Edges can be added by ctrl-dragging from one node to the other. Edge should be drawn from argument to root. Root may be function name or collector. Collector is either empty node for block, `()` for paren or `#()` for map. Text should be entered with delimiters, as well as all data with special syntax.

## Moving nodes

Individual nodes can be moved by dragging. With `shift` all dependent nodes (usually those on right) are moved also. With `shift-alt` parent nodes (usually those on left) are moved. With `shift-<down-arrow>` dependent nodes below current node are moved (while dragging with mouse) and with `shift-<up-arrow>` dependent nodes above the current are moved. (For some reason this may break down when changing between moving parent and dependent nodes.)

By dragging on canvas a box can be drawn around group of nodes. Surrounded nodes are moved together with box (dragged from border), but this is problematic, as it will affect other nodes on collision. Box can be deleted brom menu opend by right-click on border.

## Scrolling

Use wheel to scroll canvas up and down.

## TBD

* Display labels on edges
* Find way to speed it up
* Add and remove nodes on existing edges
