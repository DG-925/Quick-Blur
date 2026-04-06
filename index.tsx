/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 DG
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType, StartAt } from "@utils/types";
import { Button, Forms, React } from "@webpack/common";

import managedStyle from "./styles.css?managed";

type BlurMode = "hold" | "toggle";

interface Hotkey {
    code: string;
    ctrlKey: boolean;
    shiftKey: boolean;
    altKey: boolean;
    metaKey: boolean;
}

const author = {
    name: "DG",
    id: 186559931434926080n
};

const DEFAULT_HOTKEY: Hotkey = {
    code: "F8",
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    metaKey: false
};

const MODIFIER_CODES = new Set([
    "ControlLeft",
    "ControlRight",
    "ShiftLeft",
    "ShiftRight",
    "AltLeft",
    "AltRight",
    "MetaLeft",
    "MetaRight"
]);

const TYPING_CODES = new Set([
    "Space",
    "Backquote",
    "Minus",
    "Equal",
    "BracketLeft",
    "BracketRight",
    "Backslash",
    "Semicolon",
    "Quote",
    "Comma",
    "Period",
    "Slash"
]);

const settings = definePluginSettings({
    hotkey: {
        type: OptionType.COMPONENT,
        component: HotkeySetting,
        default: DEFAULT_HOTKEY
    },
    mode: {
        type: OptionType.SELECT,
        description: "Choose whether the blur is active while held or stays on until pressed again",
        options: [
            { label: "Toggle", value: "toggle", default: true },
            { label: "Hold", value: "hold" }
        ],
        onChange: (mode: BlurMode) => {
            clearPressedState();

            if (mode === "hold")
                setBlurActive(false);
        }
    },
    blurAmount: {
        type: OptionType.SLIDER,
        description: "How strong the blur effect is",
        markers: [4, 8, 12, 16, 20, 24],
        default: 12,
        stickToMarkers: false,
        onChange: updateOverlayVariables
    },
    dimAmount: {
        type: OptionType.SLIDER,
        description: "How dark the overlay is",
        markers: [0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4],
        default: 0.1,
        stickToMarkers: false,
        onChange: updateOverlayVariables
    }
});

const pressedCodes = new Set<string>();
let isBlurActive = false;
let isToggleLatched = false;

function normalizeHotkey(value: unknown): Hotkey {
    const hotkey = value as Partial<Hotkey> | null | undefined;

    return {
        code: typeof hotkey?.code === "string" && hotkey.code ? hotkey.code : DEFAULT_HOTKEY.code,
        ctrlKey: Boolean(hotkey?.ctrlKey),
        shiftKey: Boolean(hotkey?.shiftKey),
        altKey: Boolean(hotkey?.altKey),
        metaKey: Boolean(hotkey?.metaKey)
    };
}

function isTypingCode(code: string) {
    return /^Key[A-Z]$/.test(code) || /^Digit[0-9]$/.test(code) || TYPING_CODES.has(code);
}

function isValidHotkey(hotkey: Hotkey) {
    return hotkey.ctrlKey || hotkey.shiftKey || hotkey.altKey || hotkey.metaKey || !isTypingCode(hotkey.code);
}

function getCodeLabel(code: string) {
    if (/^Key[A-Z]$/.test(code)) return code.slice(3);
    if (/^Digit[0-9]$/.test(code)) return code.slice(5);
    if (/^F\d{1,2}$/.test(code)) return code;
    if (/^Arrow/.test(code)) return code.slice(5);

    const aliases: Record<string, string> = {
        Space: "Space",
        Escape: "Esc",
        Enter: "Enter",
        Tab: "Tab",
        Backspace: "Backspace",
        Delete: "Delete",
        Insert: "Insert",
        Home: "Home",
        End: "End",
        PageUp: "Page Up",
        PageDown: "Page Down",
        Minus: "-",
        Equal: "=",
        Backquote: "`",
        BracketLeft: "[",
        BracketRight: "]",
        Backslash: "\\",
        Semicolon: ";",
        Quote: "'",
        Comma: ",",
        Period: ".",
        Slash: "/",
        NumpadAdd: "Num +",
        NumpadSubtract: "Num -",
        NumpadMultiply: "Num *",
        NumpadDivide: "Num /",
        NumpadDecimal: "Num ."
    };

    const aliased = aliases[code];
    if (aliased) return aliased;

    const numpadMatch = /^Numpad(\d)$/.exec(code);
    if (numpadMatch) return `Num ${numpadMatch[1]}`;

    return code;
}

function formatHotkey(hotkey: Hotkey) {
    const parts: string[] = [];

    if (hotkey.ctrlKey) parts.push("Ctrl");
    if (hotkey.shiftKey) parts.push("Shift");
    if (hotkey.altKey) parts.push("Alt");
    if (hotkey.metaKey) parts.push("Meta");

    parts.push(getCodeLabel(hotkey.code));

    return parts.join(" + ");
}

function buildHotkeyFromEvent(event: KeyboardEvent) {
    if (MODIFIER_CODES.has(event.code))
        return null;

    return normalizeHotkey({
        code: event.code,
        ctrlKey: event.ctrlKey,
        shiftKey: event.shiftKey,
        altKey: event.altKey,
        metaKey: event.metaKey
    });
}

function isModifierPressed(prefix: "Control" | "Shift" | "Alt" | "Meta") {
    for (const code of pressedCodes) {
        if (code.startsWith(prefix))
            return true;
    }

    return false;
}

function isHotkeyPressed() {
    const hotkey = normalizeHotkey(settings.store.hotkey);

    return pressedCodes.has(hotkey.code)
        && isModifierPressed("Control") === hotkey.ctrlKey
        && isModifierPressed("Shift") === hotkey.shiftKey
        && isModifierPressed("Alt") === hotkey.altKey
        && isModifierPressed("Meta") === hotkey.metaKey;
}

function updateOverlayVariables() {
    document.documentElement.style.setProperty("--vc-quickBlur-amount", `${settings.store.blurAmount}px`);
    document.documentElement.style.setProperty("--vc-quickBlur-dim", settings.store.dimAmount.toString());
}

function setBlurActive(active: boolean) {
    isBlurActive = active;

    if (!document.body) return;

    document.body.classList.toggle("vc-quickBlur-active", active);
}

function clearPressedState() {
    pressedCodes.clear();
    isToggleLatched = false;
}

function isCaptureTarget(target: EventTarget | null) {
    const element = target instanceof HTMLElement
        ? target
        : target instanceof Node
            ? target.parentElement
            : null;

    return element?.closest("[data-vc-quickblur-capture='true']") != null;
}

function resetInputState() {
    clearPressedState();

    if (settings.store.mode === "hold")
        setBlurActive(false);
}

function syncHoldBlur() {
    setBlurActive(isHotkeyPressed());
}

function onKeyDown(event: KeyboardEvent) {
    if (isCaptureTarget(event.target))
        return;

    pressedCodes.add(event.code);

    const matches = isHotkeyPressed();

    if (settings.store.mode === "hold") {
        if (matches) {
            event.preventDefault();
            event.stopPropagation();
        }

        syncHoldBlur();
        return;
    }

    if (!matches) {
        isToggleLatched = false;
        return;
    }

    if (event.repeat || isToggleLatched) {
        event.preventDefault();
        event.stopPropagation();
        return;
    }

    event.preventDefault();
    event.stopPropagation();

    isToggleLatched = true;
    setBlurActive(!isBlurActive);
}

function onKeyUp(event: KeyboardEvent) {
    if (isCaptureTarget(event.target))
        return;

    pressedCodes.delete(event.code);

    if (settings.store.mode === "hold") {
        syncHoldBlur();
        return;
    }

    isToggleLatched = isHotkeyPressed();
}

function HotkeySetting({ setValue }: { setValue(newValue: Hotkey): void; }) {
    const { hotkey } = settings.use(["hotkey"]);
    const [isCapturing, setIsCapturing] = React.useState(false);
    const [error, setError] = React.useState("");
    const currentHotkey = normalizeHotkey(hotkey);

    React.useEffect(() => {
        if (!isCapturing) return;

        const stopCapture = () => setIsCapturing(false);
        window.addEventListener("blur", stopCapture);

        return () => window.removeEventListener("blur", stopCapture);
    }, [isCapturing]);

    function saveHotkey(nextHotkey: Hotkey) {
        const normalized = normalizeHotkey(nextHotkey);
        settings.store.hotkey = normalized;
        setValue(normalized);
        setError("");
        setIsCapturing(false);
        clearPressedState();
    }

    function onCaptureKeyDown(event: React.KeyboardEvent<HTMLButtonElement>) {
        if (!isCapturing)
            return;

        event.preventDefault();
        event.stopPropagation();

        if (event.key === "Escape") {
            setError("");
            setIsCapturing(false);
            return;
        }

        const nextHotkey = buildHotkeyFromEvent(event.nativeEvent);

        if (!nextHotkey) {
            setError("Press one non-modifier key, with optional Ctrl, Shift, Alt, or Meta.");
            return;
        }

        if (!isValidHotkey(nextHotkey)) {
            setError("Letters, numbers, and symbol keys need at least one modifier.");
            return;
        }

        saveHotkey(nextHotkey);
    }

    return (
        <section>
            <Forms.FormTitle tag="h3">Blur Hotkey</Forms.FormTitle>
            <Forms.FormText>
                Click the button, then press the keybind you want. Plain typing keys need a modifier.
            </Forms.FormText>
            <div style={{ display: "flex", gap: "8px", marginTop: "8px", flexWrap: "wrap" }}>
                <Button
                    data-vc-quickblur-capture="true"
                    onClick={() => {
                        setError("");
                        setIsCapturing(!isCapturing);
                    }}
                    onKeyDown={onCaptureKeyDown}
                >
                    {isCapturing ? "Press a keybind..." : formatHotkey(currentHotkey)}
                </Button>
                <Button
                    data-vc-quickblur-capture="true"
                    onClick={() => saveHotkey(DEFAULT_HOTKEY)}
                >
                    Reset to F8
                </Button>
            </div>
            {error && (
                <Forms.FormText style={{ color: "var(--text-danger)", marginTop: "8px" }}>
                    {error}
                </Forms.FormText>
            )}
        </section>
    );
}

export default definePlugin({
    name: "QuickBlur",
    description: "Blur the whole Discord window with a configurable hold or toggle keybind",
    authors: [author],
    settings,
    requiresRestart: false,
    startAt: StartAt.DOMContentLoaded,
    managedStyle,

    start() {
        updateOverlayVariables();
        document.body?.classList.add("vc-quickBlur-plugin");
        window.addEventListener("keydown", onKeyDown, true);
        window.addEventListener("keyup", onKeyUp, true);
        window.addEventListener("blur", resetInputState);
        document.addEventListener("visibilitychange", resetInputState);
    },

    stop() {
        window.removeEventListener("keydown", onKeyDown, true);
        window.removeEventListener("keyup", onKeyUp, true);
        window.removeEventListener("blur", resetInputState);
        document.removeEventListener("visibilitychange", resetInputState);
        clearPressedState();
        setBlurActive(false);
        document.body?.classList.remove("vc-quickBlur-plugin");
        document.documentElement.style.removeProperty("--vc-quickBlur-amount");
        document.documentElement.style.removeProperty("--vc-quickBlur-dim");
    }
});
