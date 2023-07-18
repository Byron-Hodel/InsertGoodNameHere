package events

import "vendor:wasm/js"
import "core:fmt"

Key_Id :: enum u8 {
    Unkown,
    A,B,C,D,
    E,F,G,H,
    I,J,K,L,
    M,N,O,P,
    Q,R,S,T,
    U,V,W,X,
    Y,Z,

    Zero, One,
    Two, Three,
    Four, Five,
    Six, Seven,
    Eight, Nine,

    Space,
    Shift_L,
    Shift_R,
    Ctrl_L,
    Ctrl_R,
    Alt_L,
    Alt_R,
    // TODO: Add More Key Ids
}

Mouse_Button_Id :: enum u8 {
    Unkown,
    Left,
    Middle,
    Right,
}

Key_State :: enum u8 {
    Released,
    Pressed,
    Held,
}

Key_Event :: struct {
    new_state: Key_State,
    id: Key_Id,
}

Mouse_Button_State :: enum u8 {
    Pressed,
    Released,
}

Mouse_Button_Event :: struct {
    new_state: Mouse_Button_State,
    id: Mouse_Button_Id,
}

Mouse_Move_Event :: struct {
    delta_x: u32,
    delta_y: u32,
    client_x: u32,
    client_y: u32,
}

Mouse_Wheel_Event :: struct {
    delta_x: f64,
    delta_y: f64,
}

Event :: union {
    Key_Event,
    Mouse_Button_Event,
    Mouse_Move_Event,
    Mouse_Wheel_Event,
}

// this limit should never be reached
EVENT_QUEUE_CAPACITY :: 256;
event_queue: [EVENT_QUEUE_CAPACITY]Event
event_queue_len: u32 = 0
event_queue_beginning: u32 = 0

key_states: [Key_Id]Key_State

init :: proc() -> (result: bool) {
    result = js.add_window_event_listener(.Key_Up, nil, on_js_event, false)
    result = js.add_window_event_listener(.Key_Down, nil, on_js_event, false)
    result |= js.add_event_listener("render-area", .Mouse_Down, nil, on_js_event, false) 
    result |= js.add_event_listener("render-area", .Mouse_Up, nil, on_js_event, false) 
    result |= js.add_event_listener("render-area", .Context_Menu, nil, on_js_event, false)
    result |= js.add_event_listener("render-area", .Wheel, nil, on_js_event, false) 
    result |= js.add_event_listener("render-area", .Mouse_Move, nil, on_js_event, false) 
    return
}

deinit :: proc() {
    js.remove_window_event_listener(.Key_Up, nil, on_js_event)
    js.remove_window_event_listener(.Key_Down, nil, on_js_event)
    js.remove_event_listener("render-area", .Mouse_Down, nil, on_js_event)
    js.remove_event_listener("render-area", .Mouse_Up, nil, on_js_event)
    js.remove_event_listener("render-area", .Context_Menu, nil, on_js_event)
    js.remove_event_listener("render-area", .Wheel, nil, on_js_event)
    js.remove_event_listener("render-area", .Mouse_Move, nil, on_js_event)
}

enqueue :: proc(event: Event) {
    index: u32 = (event_queue_len + event_queue_beginning) % EVENT_QUEUE_CAPACITY
    event_queue_len += 1
    if(event_queue_len > EVENT_QUEUE_CAPACITY) {
        event_queue_len = EVENT_QUEUE_CAPACITY
    }
    event_queue[index] = event
}

next :: proc() -> Event {
    if(event_queue_len == 0) {
        return nil
    }
    event_queue_len -= 1
    event := event_queue[event_queue_beginning] 
    event_queue_beginning += 1
    event_queue_beginning %= EVENT_QUEUE_CAPACITY
    return event
}

update_key_states :: proc() {
    for id in Key_Id {
        if key_states[id] == .Pressed {
            key_states[id] = .Held
        }
    }
}

@(private)
on_js_event :: proc(js_event: js.Event) {
    #partial switch js_event.kind {
    case .Key_Press, .Wheel, .Context_Menu:
        js.event_prevent_default()
    }

    event: Event
    #partial switch js_event.kind {
    case .Key_Up:
        key_id := translate_js_key_code(js_event.key.code)
        key_states[key_id] = .Released
        event = Key_Event {
            new_state = .Released,
            id = key_id,
        }
    case .Key_Down:
        key_id := translate_js_key_code(js_event.key.code)
        if !js_event.key.repeat {
            key_states[key_id] = .Pressed
        }
        event = Key_Event {
            new_state = .Pressed if !js_event.key.repeat else .Held,
            id = key_id,
        }
    case .Mouse_Down:
        event = Mouse_Button_Event {
            new_state = .Pressed,
            id = translate_js_mouse_button(js_event.mouse.button),
        }
    case .Mouse_Up:
        event = Mouse_Button_Event {
            new_state = .Released,
            id = translate_js_mouse_button(js_event.mouse.button),
        }
    case .Wheel:
        event = Mouse_Wheel_Event {
            delta_x = js_event.wheel.delta[0],
            delta_y = js_event.wheel.delta[1],
        }
    case:
        event = nil
    }
    enqueue(event)
}

// Why Strings, Why
// Why are non-string KeyCodes depricated
@(private)
translate_js_key_code :: proc(code: string) -> Key_Id {
    switch code {
    case "KeyA":
        return .A
    case "KeyB":
        return .B
    case "KeyC":
        return .C
    case "KeyD":
        return .D
    case "KeyE":
        return .E
    case "KeyF":
        return .F
    case "KeyG":
        return .G
    case "KeyH":
        return .H
    case "KeyI":
        return .I
    case "KeyJ":
        return .J
    case "KeyK":
        return .K
    case "KeyL":
        return .L
    case "KeyM":
        return .M
    case "KeyN":
        return .N
    case "KeyO":
        return .O
    case "KeyP":
        return .P
    case "KeyQ":
        return .Q
    case "KeyR":
        return .R
    case "KeyS":
        return .S
    case "KeyT":
        return .T
    case "KeyU":
        return .U
    case "KeyV":
        return .V
    case "KeyW":
        return .W
    case "KeyX":
        return .X
    case "KeyY":
        return .Y
    case "KeyZ":
        return .Z
    case "Digit0":
        return .Zero 
    case "Digit1":
        return .One 
    case "Digit2":
        return .Two
    case "Digit3":
        return .Three
    case "Digit4":
        return .Four
    case "Digit5":
        return .Five
    case "Digit6":
        return .Six
    case "Digit7":
        return .Seven
    case "Digit8":
        return .Eight
    case "Digit9":
        return .Nine
    case "Space":
        return .Space
    case "ShiftLeft":
        return .Shift_L
    case "ShiftRight":
        return .Shift_R
    case "ControlLeft":
        return .Ctrl_L
    case "ControlRight":
        return .Ctrl_R
    case:
        return .Unkown
    }
}

@(private)
translate_js_mouse_button :: proc(btn: i16) -> Mouse_Button_Id {
    switch btn {
    case 0:
        return .Left
    case 1:
        return .Middle
    case 2:
        return .Right
    case:
        return .Unkown
    }
}
