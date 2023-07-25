#!/bin/bash

odin build src -o=speed -out=insert_cool_name_here.wasm -target=js_wasm32 -debug -target-features:\"+bulk-memory,+atomics\"
