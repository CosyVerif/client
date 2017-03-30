-- Luca: this is an example provided by Alban, with as few changes by me as
-- possible to make it compatible with the web client.

local defaults = Layer.key.defaults
local meta     = Layer.key.meta
local refines  = Layer.key.refines

local record     = Layer.new { name = "data.record" }
local collection = Layer.new { name = "data.collection" }

collection [meta] = {
  [collection] = {
    key_type        = false,
    value_type      = false,
    key_container   = false,
    value_container = false,
    minimum         = false,
    maximum         = false,
  },
}
collection [defaults] = {
  Layer.reference (collection) [meta] [collection].value_type,
}

local graph = Layer.new { name = "graph" }

graph [refines] = {
  record,
}

graph [meta] = {}

-- Vertices are empty in base graph.
graph [meta].vertex_type = {
  [refines] = {
    record,
  }
}

-- Arrows are records with only one predefined field: `vertex`.
-- It points to the destination of the arrow, that must be a vertex of the
-- graph.
-- Edges have no label in base graph.
-- They only contain zero to several arrows. The arrow type is defined for
-- each edge type.
-- The `default` key states that all elements within the `arrows` container
-- are of type `arrow_type`.
graph [meta].edge_type = {
  [refines] = {
    record,
  },
  [meta] = {
    arrow_type = {
      [refines] = {
        record,
      },
      [meta] = {
        [record] = {
          vertex = {
            value_type      = Layer.reference (graph) [meta].vertex_type,
            value_container = Layer.reference (graph).vertices,
          }
        }
      },
      vertex = nil,
    },
  },
}

graph [meta].edge_type.arrows = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph [meta].edge_type) [meta].arrow_type,
    }
  },
}

-- A graph contains a collection of vertices.
-- The `default` key states that all elements within the `vertices` container
-- are of type `vertex_type`.
graph.vertices = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph) [meta].vertex_type,
    },
  },
}

-- A graph contains a collection of edges.
-- The `default` key states that all elements within the `edges` container
-- are of type `edge_type`.
graph.edges = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph) [meta].edge_type,
    },
  },
}

local binary_edges = Layer.new { name = "graph.binary_edges" }

binary_edges [refines] = {
  graph
}

binary_edges [meta].edge_type.arrows [meta] = {
  [collection] = {
    minimum = 2,
    maximum = 2,
  },
}

local directed = Layer.new { name = "graph.directed" }

directed [refines] = {
  graph,
  binary_edges,
}

directed [meta].edge_type [meta] [record] = {
  source = {
    value_container = Layer.reference (directed).vertices,
  },
  target = {
    value_container = Layer.reference (directed).vertices,
  },
}

directed [meta].edge_type.arrows = {
  source = {
    vertex = Layer.reference (directed [meta].edge_type).source,
  },
  target = {
    vertex = Layer.reference (directed [meta].edge_type).target,
  },
}

local petrinet = Layer.new { name = "petrinet" }

petrinet [refines] = {
  directed,
}

petrinet [meta].place_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].vertex_type,
  },
  [meta] = {
    [record] = {
      identifier = false,
      marking    = false,
    }
  }
}

petrinet [meta].transition_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].vertex_type,
  },
  -- Luca: Note for Alban: I added this meta field just to have some place where
  -- to store default non-overridden attributes.
  [meta] = {
  }
}

petrinet [meta].arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].edge_type,
  },
}

petrinet.places = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].place_type,
    }
  },
}

petrinet.transitions = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].transition_type,
    }
  },
}

petrinet [meta].pre_arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].arc_type,
  },
  [meta] = {
    [record] = {
      source = {
        value_container = Layer.reference (petrinet).places,
      },
      target = {
        value_container = Layer.reference (petrinet).transitions,
      },
    },
  },
}

petrinet [meta].post_arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].arc_type,
  },
  [meta] = {
    [record] = {
      source = {
        value_container = Layer.reference (petrinet).transitions,
      },
      target = {
        value_container = Layer.reference (petrinet).places,
      },
    },
  },
}

petrinet.pre_arcs = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].pre_arc_type,
    }
  },
}

petrinet.post_arcs = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].post_arc_type,
    }
  },
}

petrinet.arcs = {
  [refines] = {
    Layer.reference (petrinet).pre_arcs,
    Layer.reference (petrinet).post_arcs,
  },
}

petrinet.vertices [refines] = {
  Layer.reference (petrinet).places,
  Layer.reference (petrinet).transitions,
}
petrinet.edges    [refines] = {
  Layer.reference (petrinet).arcs,
}

-- Luca: this is new: defaults.
-- petrinet[meta].place_type[meta].depth = 0
-- petrinet[meta].transition_type[meta].depth = 0
-- petrinet[meta].pre_arc_type[meta].depth = 1 / 0
-- petrinet[meta].post_arc_type[meta].depth = 1 / 0
-- petrinet[meta].place_type[meta].shape = 'circle'
-- petrinet[meta].transition_type[meta].shape = 'rect'
petrinet[meta].place_type[meta].color = 'orange'
petrinet[meta].transition_type[meta].color = 'purple'
petrinet[meta].pre_arc_type[meta].color = 'yellow'
petrinet[meta].post_arc_type[meta].color = 'magenta'

local example, ref = Layer.new { name = "example" }

example [refines] = {
  petrinet,
}
example.places     .a  = {}
example.places     .c  = {}
example.transitions.b  = {}
example.pre_arcs   .ab = {
  source = ref.places.a,
  target = ref.transitions.b,
}
example.post_arcs  .bc = {
   source = ref.transitions.b,
   target = ref.places.c,
}

-- Luca: this is new: overrides.
example.places.a.color = 'red'
example.transitions.b.color = 'green'
example.places.c.color = 'blue'
example.pre_arcs.ab.color = 'white'
example.transitions.b.color = 'green'
example.places.c.color = 'blue'
example.places.a.x = -0.3
example.places.a.y = -0.3
example.transitions.b.x = 0
example.transitions.b.y = 0.3
example.places.c.x = 0.3
example.places.c.y = -0.3
--example.post_arcs.bc.color = 'brown'

-- Luca: this is new but could trivially be factored into layeredata after
-- specialization tables are defined for each relevant formalism.
require "layeredata_visit"
set_specialization_table (example, petrinet_specialization_table)

-- Luca: this is new.  I assume ref is not used outside and I can return just
-- the model.  Notice that in Lua the require function only returns the *first*
-- result
-- (http://stackoverflow.com/questions/9470498/can-luas-require-function-return-multiple-results
-- ), so here I need to either to this or work around the issue by returning a
-- table or a function.
return example
