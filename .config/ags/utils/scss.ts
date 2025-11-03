
import { execAsync } from "astal"
import { monitorFile, readFile, writeFile } from "astal/file"
import { App } from "astal/gtk3"
import { globalFontSize, globalIconSize, globalOpacity, globalScale } from "../variables"
import { notify } from "./notification"
import GLib from "gi://GLib"

// target css file
const tmpCss = `/tmp/tmp-style.css`
const tmpScss = `/tmp/tmp-style.scss`
const scss_dir = `./scss`

const walColors = `./../../.cache/wal/colors.scss`
const defaultColors = `./scss/defaultColors.scss`

export const getCssPath = () =>
{
    // Initialize CSS file if it doesn't exist
    if (!GLib.file_test(tmpCss, GLib.FileTest.EXISTS)) {
        // Create empty CSS file to prevent startup error
        writeFile(tmpCss, '* { }')
    }
    // Refresh CSS asynchronously (will apply when ready)
    refreshCss()
    return tmpCss
}

export async function refreshCss()
{
    const scss = `./scss/style.scss`

    try {

        await execAsync(`bash -c "echo '
        $OPACITY: ${globalOpacity.get().value};
        $ICON-SIZE: ${globalIconSize.get().value}px;
        $FONT-SIZE: ${globalFontSize.get().value}px;
        $SCALE: ${globalScale.get().value}px;
        ' | cat - ${defaultColors} ${walColors} ${scss} > ${tmpScss} && sassc ${tmpScss} ${tmpCss} -I ${scss_dir}"`)

        App.apply_css(tmpCss, true)

    } catch (e) {
        notify({ summary: `Error while generating css`, body: String(e) })
        console.error(e)
    }
}

monitorFile(
    // directory that contains the scss files
    `./scss`,
    () => refreshCss()
)

monitorFile(
    // directory that contains pywal colors
    `./../../.cache/wal/colors.scss`,
    () => refreshCss()
)
