package cmd

import (
	"fmt"
	"log"

	"github.com/awesome-gocui/gocui"
)

// Global flag specifying whether a license is accepted or not
var gIsLicenseAccepted = false

// Global specifying license pathname for the layout function
var licFilePathname string

const (
	// Button box height.
	buttonH      = 2
	keybindH     = 3
	licenseBox   = "License"
	inputBox     = "Input"
	yesBox       = "yesBox"
	noBox        = "noBox"
	helpBox      = "helpBox"
	acceptLicMsg = "Do you accept the license:"
)

var (
	viewArr = []string{"License", "yesBox", "noBox"}
	active  = 0
)

// acceptLicense displays a license and prompts a user to accept or reject it
func acceptLicense() bool {

	// Initialize global flag value to false to ensure that this
	// initial value is set for subsequent function invocations
	gIsLicenseAccepted = false

	g, err := gocui.NewGui(gocui.OutputNormal, true)
	if err != nil {
		log.Panicln(err)
		return false
	}

	g.Cursor = true
	g.Mouse = true

	g.SetManagerFunc(layout)

	if err := keybindings(g); err != nil {
		log.Panicln(err)
		return false
	}

	if err := g.MainLoop(); err != nil && !gocui.IsQuit(err) {
		log.Panicln(err)
		return false
	}

	g.Close()

	if gIsLicenseAccepted {
		return true // license has been accepted
	}
	return false // license was not accepted
}

// layout sets the gocui terminal window layout
func layout(g *gocui.Gui) error {
	maxX, maxY := g.Size()
	if v, err := g.SetView(licenseBox, 0, 0, maxX-1, maxY-buttonH-3, 0); err != nil {
		if !gocui.IsUnknownView(err) {
			return err
		}
		fmt.Fprintf(v, License)
		v.Editable = false
		v.Wrap = true
		v.Title = licenseBox
		v.Rewind()
		if err := v.SetOrigin(0, 0); err != nil {
			return err
		}
		if _, err := setCurrentViewOnTop(g, licenseBox); err != nil {
			return err
		}
	}
	var shift = len(acceptLicMsg) + 2
	if v, err := g.SetView(inputBox, 0, maxY-buttonH-2, shift, maxY-2, 0); err != nil {
		if !gocui.IsUnknownView(err) {
			return err
		}
		v.Title = "Press Yes or No to select"
		v.Editable = false
		fmt.Fprintln(v, acceptLicMsg)
	}
	if v, err := g.SetView(yesBox, shift+1, maxY-buttonH-2, shift+5, maxY-2, 0); err != nil {
		if !gocui.IsUnknownView(err) {
			return err
		}
		v.Highlight = true
		v.Editable = false
		fmt.Fprintln(v, "Yes")
	}
	if v, err := g.SetView(noBox, shift+6, maxY-buttonH-2, shift+9, maxY-2, 0); err != nil {
		if !gocui.IsUnknownView(err) {
			return err
		}
		v.Highlight = true
		v.Editable = false
		fmt.Fprintln(v, "No")
	}
	if v, err := g.SetView(helpBox, shift+14, maxY-buttonH-2, maxX-1, maxY-1, 0); err != nil {
		if !gocui.IsUnknownView(err) {
			return err
		}
		v.Editable = false
		v.Title = "Keybindings"
		fmt.Fprintln(v, "Enter: Push button; ^C: Exit\nTab, Mouse Left-Click: Move between buttons")
	}
	return nil
}

// keybindings defines key bindings used
func keybindings(g *gocui.Gui) error {
	if err := g.SetKeybinding("", gocui.KeyCtrlC, gocui.ModNone, quit); err != nil {
		return err
	}
	if err := g.SetKeybinding("", gocui.KeyTab, gocui.ModNone, nextView); err != nil {
		return err
	}
	if err := g.SetKeybinding("", gocui.MouseLeft, gocui.ModNone, nextView); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyCtrlSpace, gocui.ModNone, nextView); err != nil {
		return err
	}
	if err := g.SetKeybinding(yesBox, gocui.KeyCtrlSpace, gocui.ModNone, nextView); err != nil {
		return err
	}
	if err := g.SetKeybinding(noBox, gocui.KeyCtrlSpace, gocui.ModNone, nextView); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyArrowUp, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollView(v, -1)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyArrowDown, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollView(v, 1)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.MouseWheelUp, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollView(v, -2)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.MouseWheelDown, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollView(v, 2)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyPgup, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			_, maxY := g.Size()
			scrollView(v, -maxY+buttonH+1)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyPgdn, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			_, maxY := g.Size()
			scrollView(v, maxY-buttonH-1)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyHome, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollViewBegin(v)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(licenseBox, gocui.KeyEnd, gocui.ModNone,
		func(g *gocui.Gui, v *gocui.View) error {
			scrollViewEnd(v)
			return nil
		}); err != nil {
		return err
	}
	if err := g.SetKeybinding(yesBox, gocui.KeyEnter, gocui.ModNone, acceptLicText); err != nil {
		return err
	}
	if err := g.SetKeybinding(noBox, gocui.KeyEnter, gocui.ModNone, rejectLicText); err != nil {
		return err
	}
	return nil
}

func quit(g *gocui.Gui, v *gocui.View) error {
	return gocui.ErrQuit
}

// acceptLicText sets the global flag for a license acceptance to true
func acceptLicText(g *gocui.Gui, v *gocui.View) error {
	gIsLicenseAccepted = true
	if err := quit(g, v); err != nil {
		return err
	}
	return nil
}

// rejectLicText sets the global flag for a license acceptance to false
func rejectLicText(g *gocui.Gui, v *gocui.View) error {
	gIsLicenseAccepted = false
	if err := quit(g, v); err != nil {
		return err
	}
	return nil
}

func setCurrentViewOnTop(g *gocui.Gui, name string) (*gocui.View, error) {
	if _, err := g.SetCurrentView(name); err != nil {
		return nil, err
	}
	return g.SetViewOnTop(name)
}

// nextView sets active cursor position at the next view
func nextView(g *gocui.Gui, v *gocui.View) error {
	nextIndex := (active + 1) % len(viewArr)
	name := viewArr[nextIndex]

	if _, err := setCurrentViewOnTop(g, name); err != nil {
		return err
	}

	if nextIndex == 0 || nextIndex == 1 || nextIndex == 2 {
		g.Cursor = true
	} else {
		g.Cursor = false
	}

	active = nextIndex
	return nil
}

func autoscroll(g *gocui.Gui, v *gocui.View) error {
	v.Autoscroll = true
	return nil
}

// scrollView supports keys up/down and page up/down movements
func scrollView(v *gocui.View, dy int) error {
	if v != nil {
		v.Autoscroll = false
		ox, oy := v.Origin()
		if err := v.SetOrigin(ox, oy+dy); err != nil {
			return err
		}
	}
	return nil
}

// scrollViewBegin sets cursor at the beginning of a text
func scrollViewBegin(v *gocui.View) error {
	if v != nil {
		v.Autoscroll = false
		if err := v.SetOrigin(0, 0); err != nil {
			return err
		}
	}
	return nil
}

// scrollViewEnd sets cursor at the end of a text
func scrollViewEnd(v *gocui.View) error {
	if v != nil {
		_, _, Mx1, My1 := v.Dimensions()
		v.Autoscroll = true
		if err := v.SetOrigin(Mx1, My1); err != nil {
			return err
		}
	}
	return nil
}

func stripUtf8FromString(inputStr string) string {
	bArr := make([]byte, len(inputStr))
	var indx int
	for i := 0; i < len(inputStr); i++ {
		c := inputStr[i]
		if c > 0 && c < 127 {
			bArr[indx] = c
			indx++
		}
	}
	return string(bArr[:indx])
}
