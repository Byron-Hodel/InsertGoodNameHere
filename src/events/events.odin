package events

import "vendor:wasm/js"

// realistically this limit should never be reached
EVENT_QUEUE_CAPACITY :: 256;
event_queue: [EVENT_QUEUE_CAPACITY]js.Event
event_queue_len: u32 = 0
event_queue_beginning: u32 = 0

init :: proc() -> (result: bool) {
    result = js.add_window_event_listener(js.Event_Kind.Key_Press, nil, onKeyPress, false) 
    result |= js.add_event_listener("render-area", .Click, nil, onClick, false) 
    result |= js.add_event_listener("render-area", .Wheel, nil, onWheel, false) 
    return
}

deinit :: proc() {
    js.remove_window_event_listener(.Key_Press, nil, onKeyPress)
    js.remove_event_listener("render-area", .Click, nil, onClick)
    js.remove_event_listener("render-area", .Wheel, nil, onWheel)
}

enqueue :: proc(event: js.Event) {
    index: u32 = (event_queue_len + event_queue_beginning) % EVENT_QUEUE_CAPACITY
    event_queue_len += 1
    if(event_queue_len > EVENT_QUEUE_CAPACITY) {
        event_queue_len = EVENT_QUEUE_CAPACITY
    }
    event_queue[index] = event
}

next :: proc() -> (event: Maybe(js.Event)) {
    if(event_queue_len == 0) {
        return nil
    }
    event_queue_len -= 1
    event = event_queue[event_queue_beginning] 
    event_queue_beginning += 1
    event_queue_beginning %= EVENT_QUEUE_CAPACITY
    return
}

@(private)
onKeyPress :: proc(event: js.Event) {
    enqueue(event)
}

@(private)
onKeyRelease :: proc(event: js.Event) {
    enqueue(event)
}

@(private)
onClick :: proc(event: js.Event) {
    enqueue(event)
}

@(private)
onWheel :: proc(event: js.Event) {
    enqueue(event)
}
