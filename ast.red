Red [
	Title: "Red syntax tree explorer"
	Date: 29-Mar-2019
	Last: 14-Apr-2019
	Author: "Toomas Vooglaid"
]

context [
	up?: no
	pos: 0x0
	boxing?: no
	grid: 5
	min-size: 25x25
	initial-size: 550x650
	
	dx: 10
	max-y: dy: 10
	lower-by: round (2 * min-size/y + dy / 2 - (min-size/y / 2)) grid
	lay: gr: bw: none
	rt-stuff: copy []
	top-nodes: copy []

	connector: [
		at 0x0 edge with [
			draw: [pen black spline (ofs: face/size / 2 + face/offset) (ofs)]
			extra: [type: 'edge from: (face) to: (none) label: (labl)]
		]
	]

	expunge: func [face /from pane][pane: any [pane face/parent/pane] remove find pane face] 

	is-func?: function [face][
		all [
			fn: first face/data
			find [word! path!] type?/word fn 
			info :fn
		]
	]

	is-op?: function [face][
		all [
			inf: is-func? face
			inf/type = op!
			inf
		]
	]

	ask-name-min: func [what event /local namef nam] [
		name: either what = 'new [none][either object? what [what/text][form what]]
		view/flags/options compose [
			namef: field (nam: any [name copy ""]) (max min-size size-text/with test nam) focus 
				on-enter [name: face/text unview]
				on-change [
					face/parent/size: max min-size face/size: size-text/with test face/text
				]
				on-key [probe event/picked]
		][no-border][
			probe offset: event/offset + event/face/offset + event/window/offset
			probe size: max 25x30 (size-text/with test namef/text) + 10x0
		]
		if object? what [what/text: name]
		name
	]

	ask-name: func [what] [
		name: either what = 'new [none][either object? what [what/text][form what]]
		view/flags compose [
			title "Edit node"
			namef: field (any [name copy ""]) focus on-enter [name: face/text unview]
			return
			button "OK" [name: namef/text unview] 
			button "Cancel" [name: none unview]
		][modal popup]
		if object? what [what/text: name]
		name
	]

	calc-size: function [face][
		sz: size-text/with test face/text
		face/size/x: max 25 sz/x + 5
		face/draw/10: face/size / 2 - (sz / 2)
		face/draw/7: face/size - 1
	]

	prepare: function [face][
		calc-size face
		found: find/tail face/draw 'text 
		found/2: face/text
	]

	adjust-edges: function [face][
		foreach edge face/extra/in_ [
			if found: either pair? last edge/draw [
				back tail edge/draw
			][
				back find edge/draw 'circle
			][
				found/1: face/size / 2 + face/offset
			]
		]
		foreach edge face/extra/out_ [
			if found: find/tail edge/draw 'spline [
				found/1: face/size / 2 + face/offset
			]
		]
	]

	move-faces: function [face df /with which /together][
		if together [
			face/offset: round/to face/offset + df grid
		]
		edges: either 'out = which [face/extra/out_][face/extra/in_]
		foreach edge edges [
			either 'out = which [
				node: edge/extra/to
				edges2: node/extra/out_
			][
				node: edge/extra/from
				edges2: node/extra/in_ 
			]
			cond: switch/default which [
				upper [node/offset/y < face/offset/y]
				lower [node/offset/y > face/offset/y]
			][true]
			which2: either 'out = which [which][none]
			if cond [
				node/offset: round/to node/offset + df grid
				adjust-edges node
				unless empty? edges2 [move-faces/with node df which2]
			]
		]	
	]

	remove-in-faces: function [face][
		foreach con face/extra/in_ [
			in-face: con/extra/from
			con/extra/from: con/extra/to: none
			expunge con
			either empty? in-face/extra/in_ [
				expunge/from con in-face/extra/out_
				if empty? in-face/extra/out_ [expunge in-face]
			][
				remove-in-faces in-face
				expunge in-face
			]
		]
		clear face/extra/in_
	]

	encode: function [face][
		res: copy either find ["()" "#()"] face/text [[]][face/data]
		edges: face/extra/in_
		forall edges [
			case [
				all [is-op? face 1 = index? edges][
					insert res encode edges/1/extra/from
				]
				true [
					append res encode edges/1/extra/from
				]
			]
		]
		switch face/text [
			"" [res: append/only copy [] res]
			"()" [res: head change/only copy face/data to-paren res]
			"#()" [res: head change copy face/data make map! res]
			;"|" [] ; parse-block
		]
		res
	]
	
	get-plain: func [face][
		next head remove back tail mold encode face
	]

	resize-edges: does [
		foreach-face/with gr [
			face/size: gr/size
		][
			face/extra/type = 'edge
		]
	]
	
	adjust-pane-height: has [lowest initial][
		if (initial: gr/size/y) + min-size/y < lowest: ast-ctx/get-y :last last top-nodes [
			gr/size/y: lowest + min-size/y
			resize-edges
		]
	]

	test: make face! [type: 'text size: 200x25]

	#include %/C/Users/Toomas/Documents/Red/rich-text/info.red

	extend system/view/VID/styles [
		graph: [
			template: [
				type: 'panel
				size 500x500
				flags: 'all-over
				menu: ["Node" _node "Text" _text]
				actors: [
					current: box: none 

					on-down: func [face event][
						boxing?: yes
						append face/pane current: first layout/only compose/deep [
							at (pos - 2) box 3x3 loose with [
								extra: #(diff: 0x0 off: 0x0)
								menu: ["Delete" _delete "Delete nodes" _delete-nodes]
							]
								draw [box 2x2 2x2 pen 200.0.0.100 line-width 5 box 2x2 2x2] 
								on-down [box: face face/extra/off: face/offset 'done] 
								on-over ['done]
								on-drag [
									box/extra/diff: box/offset - box/extra/off 
									box/extra/off: box/offset
									foreach-face/with face/parent [
										face/offset: face/offset + box/extra/diff
										foreach edge face/extra/in_ [edge/draw/5: face/size / 2 + face/offset]
										foreach edge face/extra/out_ [edge/draw/4: face/size / 2 + face/offset]
									][all [overlap? face box face/extra/type = 'node]]
								]
								on-menu [
									switch event/picked [
										_delete [expunge face]
										_delete-nodes [
											box: face
											foreach-face/with face/parent [
												foreach con face/extra/out_ [
													expunge/from con con/extra/to/extra/in_
													expunge con
												]
												foreach con face/extra/in_ [
													expunge/from con con/extra/from/extra/out_
													expunge con
												]
												expunge face
											][all [overlap? face box face/extra/type = 'node]]
											expunge face
										]
									]
								]
						] 'done
					]

					on-over: func [face event][
						if all [event/down? not up? face = event/face] [
							current/size: (current/draw/3: current/draw/10: event/offset - current/offset) + 10
						]
						pos: event/offset
						'done
					]

					on-up: func [face event][current: none boxing?: no]

					on-menu: func [face event /local new][
						switch/default event/picked [
							_text [ask-name 'new if name [
								test/text: name
								append face/pane layout/only compose [
									at (pos) text (size-text test) (name) loose 
									on-drag [face/offset: round/to face/offset 5 'done]
									on-down ['done]
									with [menu: ["Edit" _edit "Delete" _del]]
									on-menu [switch event/picked [
										_edit [attempt [ask-name face]] ;Error -- Invalid syntax at: [_edit] ???
										_del [remove find face/parent/pane face]
									]]
								]
							]]
						][
							new: last append face/pane layout/only compose [at (round/to pos grid) node]
						]
					]
					
					on-wheel: func [face event][
						gr/offset/y: 10 * event/picked + gr/offset/y
					]
				]
			]
		]
		node: [
			template: [
				type: 'base 
				size: min-size 
				color: transparent
				flags: 'all-over 
				draw: [fill-pen white rotate 0 box 0x0 24x24 3 text 0x0 ""]
				menu: [
					"Edit" 		_edit 
					"Expand" 	_expand
					"Expand as..." [
						"Parse" 	parse
						"VID" 		vid
						"Draw" 		draw
						;"Shape" 	shape
						"Rich-text" rich-text
						"Spec" 		spec
					]
					"Flatten" 	_flatten
					"Shorten" 	_shorten
					"Labels" 	_labels 
					"Eval" 		_eval 
					"Show" 		_show 
					"Copy"		_copy
					"Delete" 	_delete
				]; "Turn" ["N" _n "E" _e "S" _s "W" _w]]
				data: copy []
				actors: [
					diff: ofs: df: 0x0
					move-left: move-upper: move-lower: false
					on-down: func [face event /local lay labl] [
						set-focus face ;probe event/window/selected/text
						either event/ctrl? [
							labl: copy ""
							lay: layout/only compose/deep/only bind connector :on-down
							insert face/parent/pane lay
							append face/extra/out_ face/parent/pane/1
						][
							diff: event/offset
							ofs: face/offset
						] 'done
					]
					
					on-key-down: func [face event][
						switch event/picked [
							18 [move-left: true]
							38 [move-upper: true]
							40 [move-lower: true]
						]
					]
					
					on-key-up: func [face event][
						switch event/picked [
							18 [move-left: false]
							38 [move-upper: false]
							40 [move-lower: false]
						]
					]
					
					on-over: func [face event /local edge found] [ 
						unless boxing? [
							if event/down? [
								case [
									not event/ctrl? [
										face/offset: round/to face/offset - diff + event/offset grid
										adjust-edges face
										
										if all [
											event/shift? 
											0x0 <> df: face/offset - ofs
										][
											case [
												move-left [move-faces/with face df 'out]
												move-upper [move-faces/with face df 'upper]
												move-lower [move-faces/with face df 'lower]
												true [move-faces face df]
											]
											ofs: face/offset
										]
									]
									event/ctrl? [
										face/parent/pane/1/draw/5: event/offset + event/face/offset
									]
								]
							]
							if up? [
								face/parent/pane/1/draw/5: face/size / 2 + face/offset
								face/parent/pane/1/extra/to: face 
								append face/extra/in_ face/parent/pane/1 
								up?: no
							] 
						] ;'done 
					]
					
					on-up: func [face event] [if event/ctrl? [up?: yes]] 
					
					on-menu: func [face event /local type block nodes new word] [
						switch event/picked [
							_edit [
								all [
									attempt [face/text: ask-name face]
									prepare face
									either empty? face/data [
										face/data: load/all face/text
									][change face/data load face/text]
								]
							]
							_labels [
								if face/extra/info []
							]
							_show [probe encode face]
							_eval [print encode face]
							_copy [write-clipboard get-plain face]
							_delete [
								foreach con face/extra/out_ [
									expunge/from con con/extra/to/extra/in_
									expunge con
								]
								foreach con face/extra/in_ [
									expunge/from con con/extra/from/extra/out_
									expunge con
								]
								expunge face
							]
							_expand parse vid draw rich-text spec [;shape 
								case [
									1 < length? encoded: encode face [
										nodes: tail face/parent/pane
										block: copy next encoded
										face/text: mold first encoded
										prepare face
										clear next face/data 
										max-y: face/offset/y
										new: collect [forall block [keep 'node keep mold first block]]
										append nodes layout/only new
										until [tail? nodes: ast-ctx/connect face nodes]
										adjust-pane-height
										;probe encode face
									]
									find [block! paren! map!] type: type?/word block: first face/data [
										nodes: tail face/parent/pane
										switch type [ 
											block! [face/text: copy ""]
											paren! [face/text: copy "()"]
											map! [block: body-of block face/text: "#()"]
										]
										prepare face
										clear face/data 
										new: collect [forall block [keep 'node keep mold/flat first block]]
										append nodes layout/only new
										max-y: face/offset/y
										while [not tail? nodes][
											nodes: either event/picked = '_expand [
												ast-ctx/connect face nodes
											][
												ast-ctx/connect/dialect face nodes event/picked
											]
										]
										ast-ctx/lower/md/extention face 0 true
										adjust-pane-height
									]
									word? word: first face/data [
										get/any word
									]
									get-word? word: first face/data [; ?
										do face/data
									]
								]
							]
							_flatten [
								face/text: copy get-plain face ;next head remove back tail mold encode face
								remove-in-faces face
								prepare face
								face/data: load/all face/text
							]
							_shorten [
								face/text: append copy/part face/text 30 "..."
								prepare face
								adjust-edges face
								change/part find face/menu "Shorten" ["Full" _full] 2
							]
							_full [
								face/text: mold/flat first face/data
								prepare face
								adjust-edges face
								change/part find face/menu "Full" ["Shorten" _shorten] 2
							]
							;_n [face/draw/4: -90]
							;_e [face/draw/4: 0]
							;_s [face/draw/4: 90]
							;_w [face/draw/4: 180]
							;_stop [rate: face/rate face/rate: none]
							;_go [face/rate: rate]
							;_rate [face/rate: load ask-name face/rate]
						] 'done
					]
					
					;on-time: func [face event][face/extra/true?: not face/extra/true?]
				]
			]
			init: [
				face/extra: copy/deep [
					type: 'node 
					in_: [] 
					out_: [] 
					info: none 
					code: []
				]
				unless face/text [face/text: copy ""]
				face/data: load/all face/text
				data: first face/data
				unless bw [
					face/draw/2: case [
						any-object? data 	[pink]
						all [
							find [word! path! get-word! get-path!] type?/word data
							inf: info :data
						][either function! = inf/type 
											[crimson]
											[papaya]]
						all [word? data attempt/safer [find [datatype! typeset!] type?/word get/any data]]
											[yellow]
						map? data 			[teal]
						any-path? data 		[yello]
						any-block? data 	[gold]
						scalar? data 		[silver]
						binary? data 		[linen]
						any-string? data 	[orange]
						find [set-word! set-path!] type?/word data 
											[green]
						any-word? data 		[sky]
						immediate? data 	[tanned]
						default? data 		[khaki]
						'else 				[white]
					]
				]
				prepare face
			]
		]
		edge: [
			template: [
				type: 'base
				flags: 'all-over
				menu: ["Delete" _delete "Add point" _add "Remove point" _remove]
				actors: [
					point: circ: none
					
					on-created: func [face event][face/size: face/parent/size]
					
					on-down: func [face event] [
						point: circ: none
						parse face/draw [some [
							s: pair! if (within? event/offset s/1 - 3 6x6) [
								if (s/-1 = 'circle) (circ: s)
							|	(point: s)
							]
						| 	skip
						]]
						'done
					]
					
					on-over: func [face event] [
						if all [event/down? point] [
							point/1: circ/1: event/offset
						]
						'done
					]
					
					on-menu: func [face event] [
						switch event/picked [
							_delete [
								expunge/from face face/extra/from/extra/out_
								expunge/from face face/extra/to/extra/in_
								expunge face
							]
							_add [
								found: next find/tail face/draw 'spline
								while [
									not within? event/offset 
										_min: (min found/-1 found/1) - 2
										2 + (max found/-1 found/1) - _min
								][found: next found]
								insert found event/offset 
								append face/draw compose [circle (event/offset) 1]
								
							]
							_remove [
								found: skip find face/draw 'spline 2
								parse found [
									some [
										s: pair! if (within? event/offset s/1 - 3 6x6) [
											if (s/-1 = 'circle) (remove/part back s 3) 
										| 	(remove s)
										]
									| 	skip
									]
								]
							]
						] 'done
					]
				]
			]
		]
	]
	ast-ctx: context [
		nodes: copy []
		count: 0
		vid1-keywords: [ ; Without argumnets
			below across return
		]
		vid2-keywords: [ ; With arguments
			space origin pad do react style
			title size backdrop at
		]
		vid-keywords: union vid1-keywords vid2-keywords
		face-keywords: [
			extra data draw options select default hint init with
			font font-name font-size font-color para rate cursor
		]
		actors: extract next system/view/evt-names 2
		sys-styles: keys-of system/view/vid/styles
		usr-styles: copy []
		
		draw-keywords: [
			line triangle box polygon circle ellipse arc
			curv curve spline image text font 
			pen fill-pen line-width line-join line-cap anti-alias
			matrix matrix-order reset-matrix invert-matrix 
			push rotate scale translate skew transform clip
			
			move 'line 'arc 'curv 'curve qcurv 'qcurv qcurve 'qcurve
			hline 'hline vline 'vline 
		]
		
		colors: extract load help-string tuple! 2
		
		inc-max-y: does [
			max-y: max-y + min-size/y + dy
		]
		
		get-y: function [which node][
			either empty? in_: node/extra/in_ [
				node/offset/y
			][
				node: select which in_ 'extra
				get-y :which node/from
			]
		]
		
		lower: function [root /md maxdiff /extention ext][
			maxdiff: any [maxdiff 0]
			if not empty? root/extra/in_ [
				first-con: first root/extra/in_
				first-sub: first-con/extra/from
				fsy: first-sub/offset/y
				last-con: last root/extra/in_
				last-sub: last-con/extra/from
				diff: last-sub/offset/y - fsy
				if maxdiff = 0 [
					upper-y: get-y :first first-sub
					lower-y: get-y :last last-sub
					maxdiff: lower-y - upper-y
				]
				root/offset/y: diff / 2 + fsy
				adjust-edges root
				either empty? root/extra/out_ [
					if ext [
						if not tail? found: find/tail top-nodes root [
							foreach node found [
								move-faces/together node as-pair 0 maxdiff
								adjust-edges node
							]
						]
					]
				][
					foreach outedge root/extra/out_ [
						outnode: outedge/extra/to
						if ext [
							loweredges: find/tail outnode/extra/in_ outedge
							foreach loweredge loweredges [
								face: loweredge/extra/from
								move-faces/together face as-pair 0 maxdiff
								adjust-edges face
							]
						]
						lower/md/extention outnode maxdiff ext
					]
				]
			]
		]
		
		push-right: func [face step][
			face/offset/x: face/offset/x + step
			adjust-edges face
			if not empty? face/extra/in_ [
				foreach edge face/extra/in_ [
					push-right edge/extra/from step
				]
			]
		]
		
		expand: object [
			;if 50 < count: count + 1 [quit]
			parse: func [node nodes dsl /local nod][
				nod: first node/data
				case [
					'quote = nod [
						connect/only/dialect node next nodes dsl
					]
					any [
						find [
							some any opt while into change remove insert
							to thru not ahead if only collect keep then
						] nod
						integer? nod
					][
						connect/dialect node next nodes dsl
					]
					find [set copy] nod [
						nodes: connect/dialect node next nodes dsl
						connect/dialect node nodes dsl
					]
					'| = nod [
						nodes: next nodes
						while [
							not any [
								tail? nodes
								'| = first nodes/1/data
							]
						][
							nodes: connect/dialect node nodes dsl
						]
						lower node
						nodes
					]
					true [next nodes]
				]
			]
			
			vid: func [node nodes dsl /local nod nxt styles][
				nod: first node/data
				case [
					any [
						find face-keywords nod
						find actors nod 
					][
						connect/dialect node next nodes dsl
					]
					find styles: union sys-styles usr-styles nod [ ;keys-of system/view/vid/styles nod [
						nodes: next nodes
						while [not any [
							tail? nodes
							find styles nxt: first nodes/1/data
							set-word? nxt
							find vid-keywords nxt
						]][
							nodes: connect/dialect node nodes dsl
						]
						lower node
						nodes
					]
					'at = nod [
						nodes: connect/dialect node next nodes dsl
						connect/dialect node nodes dsl
					]
					'style = nod [
						append usr-styles to-word first nodes/2/data
						connect/dialect node next nodes dsl
					]
					any [
						find vid2-keywords nod
						set-word? nod
					][
						connect/dialect node next nodes dsl
					]
					true [next nodes]
				]
			]
			
			draw: func [node nodes dsl /local nod][
				nod: first node/data
				case [
					find/case draw-keywords nod [
						nodes: next nodes
						while [not any [
							tail? nodes
							find draw-keywords nxt: first nodes/1/data
							set-word? nxt
						]][
							nodes: connect/dialect node nodes dsl
						]
						lower node
						nodes
					]
					set-word? nod [
						connect/dialect node next nodes dsl
					]
					true [next nodes]
				]
			]
			
			rt: func [node nodes dsl /local nod end found][
				nod: first node/data
				case [
					; Multistyle
					path? nod [connect/dialect node next nodes dsl]
					; Color
					any [ 
						tuple? nod
						find colors nod
					][
						either all [1 < length? nodes block? first nodes/2/data][
							connect/dialect node next nodes dsl
						][
							nodes: next nodes
							while [not tail? nodes][
								nodes: connect/dialect node nodes dsl
							]
							lower node
							nodes
						]
					]
					; Font
					find/case [f font <font>] nod [
						nodes: connect/only/dialect node next nodes dsl
						either all [
							not tail? nodes block? first nodes/1/data
						][
							connect/dialect node nodes dsl
						][
							while [
								not any [
									tail? nodes
									end: find [/f /font </font>] first nodes/1/data
								]
							][
								nodes: connect/dialect node nodes dsl
							]
							if end [nodes: connect/only/dialect node nodes dsl]
							lower node
							nodes
						]
					]
					; Simple styles 'b 'i 'u 's
					any [
						word? nod
						all [tag? nod nod/1 <> #"/"]
					][
						either all [1 < length? nodes block? first nodes/2/data][
							connect/dialect node next nodes dsl
						][
							insert rt-stuff to-word to-string nod
							nodes: next nodes
							while [
								not any [
									tail? nodes
									all [
										refinement? nxt: first nodes/1/data
										found: find rt-stuff to-word nxt
									]
									all [
										tag? nxt
										nxt/1 = #"/"
										found: find rt-stuff to-word to-string next nxt
									]
								]
							][
								nodes: connect/dialect node nodes dsl
							]
							if found [
								remove found
								nodes: connect/only/dialect node nodes dsl
							]
							lower node
							nodes
						]
					]
					true [next nodes]
				]
			]
			
			spec: func [node nodes dsl /local nod][
				nod: first node/data
				case [
					any [refinement? nod any-word? nod] [
						nodes: next nodes
						while [not any [
							tail? nodes
							refinement? nxt: first nodes/1/data
							all [refinement? nod set-word? nxt]
							all [any-word? nod any-word? nxt]
						]][
							nodes: connect/dialect node nodes dsl
						]
						lower node
						nodes
					]
					true [next nodes]
				]
			]
		]
		
		add-edge: function [node root nodes /with label][
			label: any [label copy ""]
			edge: first layout/only compose/deep bind connector context [
				face: node labl: label
			]
			append node/extra/out_ edge
			edge/draw/5: root/size / 2 + root/offset
			edge/extra/to: root 
			append root/extra/in_ edge 
			insert head nodes edge
		]
		
		make-ops: function [val1 op nodes /with root][
			if with [
				op/offset: root/offset + as-pair root/size/x + dx 0
			]
			op-x: op/offset/x + op/size/x
			val1/offset: op/offset
			push-right val1 round/to op/size/x + dx grid
			val2: nodes/1
			val2/offset/x: round/to op-x + dx grid
			inc-max-y
			lower op 
			val2/offset/y: max-y
			add-edge/with val1 op nodes "value1"
			add-edge/with val2 op nodes "value2"
			rest: skip nodes 2
			case [
				all [3 <= length? rest is-op? rest/2] [set [op rest] make-ops/with op rest/2 skip rest 2 root]
			]
			reduce [op rest]
		]
		
		connect: func [root nodes /with label idx /dialect dsl /only /local node _2 edg fn inf][
			label: any [label copy ""]
			
			either all [ ; In case we have operation next
				3 <= length? nodes
				is-op? nodes/2
			][
				set [node nodes] make-ops/with nodes/1 nodes/2 skip nodes 2 root
				max-y: root/offset/y
			][
				node: nodes/1
			]
			
			node/offset/x: round/to root/offset/x + root/size/x + dx grid
			
			if 0 < length? root/extra/in_ [inc-max-y]
			node/offset/y: max-y
						
			add-edge/with node root nodes: next nodes label
			if only [return next nodes]
			
			either dialect [
				switch dsl [
					parse [expand/parse node nodes dsl]
					vid [expand/vid node nodes dsl]
					draw [expand/draw node nodes dsl]
					;shape [expand/shape node nodes dsl]
					rich-text [expand/rt node nodes dsl]
					spec [expand/spec node nodes dsl]
				]
			][
				either any [
					find [set-word! set-path!] type?/word first node/data
					inf: is-func? node 
				][
					make-tree nodes
				][
					next nodes
				]
			]
		]
		
		make-tree: func [nodes /dialect dsl /local nods fn inf ref labels label root op][
			case [
				find [set-word! set-path!] type?/word first nodes/1/data [
					nods: connect nodes/1 next nodes
				]
				; Function
				all [
					find [word! path!] type?/word fn: first nodes/1/data 
					inf: info :fn
				][
					labels: inf/runtime-args
					nods: next nodes
					root: nodes/1
					forall labels [
						nods: connect/with root nods form labels/1 index? labels
					]
					lower root
					
				]
				; Operation
				all [
					3 <= length? nodes 
					is-op? nodes/2
				][
					set [op nods] make-ops nodes/1 nodes/2 skip nodes 2
				]
				true [nods: next nodes]
			]
			nods
			
		]
		
		set 'ast func [code [block! file! any-function! object!] /no-color /local i][
			bw: no-color
			clear head nodes
			clear usr-styles
			max-y: dy
			clear rt-stuff
			clear top-nodes
				
			case [
				file? :code [
					code: skip load code 2
				]
				any-function? :code [
					code: load mold/flat :code
				]
				object? :code [
					code: load mold/flat code
				]
			]
			
			nodes: collect [
				forall code [
					keep 'node
					keep mold/flat code/1
				]
			]

			view/flags/no-wait lay: layout append/only copy [
				on-resizing [
					gr/size: max gr/size face/size - 20
					resize-edges
				] 
				gr: graph initial-size
			] nodes 'resize

			nodes: gr/pane 
			
			append top-nodes first nodes

			while [not tail? nodes: make-tree nodes][
				inc-max-y
				i: pick [2 1] to-logic all [
					3 <= length? nodes 
					is-op? nodes/2
				]
				nodes/:i/offset: as-pair 10 max-y
				append top-nodes nodes/:i
			]
			
			adjust-pane-height

			do-events
		]
	]
]
;Example
comment [ 
	ast [print copy/part mark: find/tail read %somefile.txt "<" any [find mark ">" tail mark]]
	
	ast [view [
		title "Generate VID tree" 
		style bx: box 200x100 glass draw [fill-pen gold box 0x0 199x99 3] on-down [probe event/offset] 
		below 
		bx1: bx bx2: bx with [draw/2: brick]
		at 40x50 text "First box" return 
		button "OK" [unview]
	]] 
]
