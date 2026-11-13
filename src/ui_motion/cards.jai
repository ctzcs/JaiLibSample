Card :: struct {
    queued, placed, flying: bool;
    slot: int;
    pos, velocity: F.Vector2;
    tilt, lift: float32;
    motion: UI.UI_Visual;
    handle: TW.Tween_Handle;
}
cards: [4] Card;
slots: [3] int;
hand: [4] int;
hand_open: [4] float32;
gaps: [5] float32;
slot_rects: [3] F.Rect;
hand_rects: [4] F.Rect;
tray: F.Rect;
card_size: F.Vector2;
drag: int = -1;
drag_start, drag_grab: F.Vector2;
drag_moved: bool;
hover_slot: int = -1;
insertion: int = -1;
playing, gate_opened, modal_open: bool;
play_slot, attacks, rewards, guards: int;
play_timer: float32;
tweens: TW.Tween_Manager;

rect_center :: (r: F.Rect) -> F.Vector2 { return .{r.x + r.w * 0.5, r.y + r.h * 0.5}; }
length2 :: (p: F.Vector2) -> float32 { return sqrt(p.x * p.x + p.y * p.y); }
place :: (index: int, slot: int) {
    card := *cards[index];
    if card.queued && card.slot == slot { card.flying = true; return; }
    other := slots[slot];
    if card.queued {
        slots[card.slot] = other;
        if other >= 0 { cards[other].slot = card.slot; cards[other].flying = true; }
    } else if other >= 0 { cards[other].queued = false; cards[other].flying = true; }
    slots[slot] = index; card.queued = true; card.slot = slot; card.flying = true;
}
return_home :: (index: int) {
    if cards[index].queued slots[cards[index].slot] = -1;
    cards[index].queued = false; cards[index].flying = true;
}
toggle :: (index: int) {
    if cards[index].queued { return_home(index); return; }
    for occupant, slot: slots if occupant < 0 { place(index, slot); return; }
    UI.ui_motion_kick(*h.ui, tprint("pop-%", index), .{scale = .{6, 6}, rotation = -2.4});
}
insert_hand :: (index: int, at: int) {
    from := 0; for entry, i: hand if entry == index from = i;
    to := clamp(ifx at > from then at - 1 else at, 0, 3);
    if to > from { i := from; while i < to { hand[i] = hand[i + 1]; i += 1; } }
    if to < from { i := from; while i > to { hand[i] = hand[i - 1]; i -= 1; } }
    hand[to] = index; hand_open[index] = gaps[at]; for *gap: gaps gap.* = 0;
    return_home(index);
}
drop_card :: (index: int) {
    if !drag_moved toggle(index);
    else if hover_slot >= 0 place(index, hover_slot);
    else if insertion >= 0 insert_hand(index, insertion);
    else return_home(index);
    drag = -1; hover_slot = -1; insertion = -1;
}
find_drop :: (p: F.Vector2) {
    hover_slot = -1; insertion = -1;
    for r, i: slot_rects {
        margin := r.w * 0.25;
        if p.x >= r.x - margin && p.x <= r.x + r.w + margin && p.y >= r.y - margin && p.y <= r.y + r.h + margin { hover_slot = i; return; }
    }
    margin := card_size.y * 0.35;
    if p.x < tray.x - margin || p.x > tray.x + tray.w + margin || p.y < tray.y - margin || p.y > tray.y + tray.h + margin return;
    insertion = 4;
    for entry, i: hand if !cards[entry].queued && entry != drag && p.x < rect_center(hand_rects[entry]).x { insertion = i; break; }
}
layout_cards :: () {
    k := clamp(min((h.ui.width - 120) / 600, (h.ui.height - 250) / 420), 0.6, 1);
    card_size = .{124 * k, 186 * k};
    size := card_size.x + 14 * k;
    x := (h.ui.width - size * 3 - 28 * k - 100) * 0.5;
    for *r, i: slot_rects r.* = .{x + cast(float32) i * (size + 14 * k), 155, size, card_size.y + 14 * k};
    total: float32;
    for i: 0..4 {
        target: float32 = ifx drag >= 0 && drag_moved && insertion == i then 1 else 0;
        gaps[i] = TW.approach(gaps[i], target, 16, h.dt); total += gaps[i] * (card_size.x + 20 * k);
        if i < 4 {
            entry := hand[i]; target = ifx !cards[entry].queued && !(entry == drag && drag_moved) then 1 else 0;
            hand_open[entry] = TW.approach(hand_open[entry], target, 16, h.dt);
            total += hand_open[entry] * (card_size.x + 20 * k);
        }
    }
    x = (h.ui.width - total) * 0.5;
    y := h.ui.height - card_size.y - 125;
    tray = .{x - 20, y - 14, max(total + 40, 80), card_size.y + 36};
    for i: 0..4 {
        x += gaps[i] * (card_size.x + 20 * k);
        if i == 4 break;
        entry := hand[i]; width := hand_open[entry] * (card_size.x + 20 * k);
        hand_rects[entry] = .{x + width * 0.5 - card_size.x * 0.5, y, card_size.x, card_size.y};
        x += width;
    }
}
step_card :: (index: int, hovered: bool) {
    card := *cards[index]; home := ifx card.queued then slot_rects[card.slot] else hand_rects[index];
    target := rect_center(home) - card_size * 0.5;
    if !card.placed { card.pos = target; card.placed = true; }
    dragging := drag == index && drag_moved;
    if dragging {
        next := h.pointer - drag_grab;
        if h.dt > 0 card.velocity = (next - card.pos) / h.dt;
        card.pos = next; find_drop(card.pos + card_size * 0.5);
    } else if !card.flying { card.pos = target; card.velocity = .{0, 0}; }
    else {
        // Scalar overloads keep the host independent of vector operators inside the tween module.
        card.pos.x, card.velocity.x = TW.smooth_damp(card.pos.x, card.velocity.x, target.x, 0.075, h.dt);
        card.pos.y, card.velocity.y = TW.smooth_damp(card.pos.y, card.velocity.y, target.y, 0.075, h.dt);
        if length2(target - card.pos) < 1 && length2(card.velocity) < 60 {
            card.pos = target; card.velocity = .{0, 0}; card.flying = false; animate(index, 2);
        }
    }
    card.lift = TW.approach(card.lift, ifx dragging then 1.0 else (ifx hovered then 0.45 else 0.0), 18, h.dt);
    card.tilt = TW.approach(card.tilt, clamp(card.velocity.x * 0.00032, -0.32, 0.32), 16, h.dt);
}
sequence_step :: (index: int, a: UI.UI_Visual, b: UI.UI_Visual, seconds: float32) {
    _, ok := TW.sequence_append_tween_to(*tweens, cards[index].handle,
        TW.make_ex(a, b, 0, .{duration = seconds, transition = .EaseOut}, UI.ui_visual_lerp), *cards[index].motion);
    assert(ok);
}
animate :: (index: int, kind: int) {
    TW.manager_kill(*tweens, cards[index].handle); cards[index].handle = TW.manager_add_sequence(*tweens);
    windup := UI.UI_VISUAL_DEFAULT; peak := UI.UI_VISUAL_DEFAULT;
    windup.scale = .{1.06, 0.9}; windup.pivot = .{0.5, 1};
    if kind == 2 { peak.scale = .{0.98, 1.03}; peak.pivot = .{0.5, 1}; }
    else { peak.offset = .{ifx kind == 1 then 0.0 else 10.0, -48}; peak.rotation = -0.14; peak.scale = .{1.08, 1.08}; }
    sequence_step(index, cards[index].motion, windup, 0.055);
    sequence_step(index, windup, peak, ifx kind == 2 then 0.08 else 0.15);
    sequence_step(index, peak, UI.UI_VISUAL_DEFAULT, 0.2);
}
execute :: () {
    if playing return;
    for occupant: slots if occupant >= 0 { playing = true; play_slot = 0; play_timer = 0; gate_opened = false; return; }
}
