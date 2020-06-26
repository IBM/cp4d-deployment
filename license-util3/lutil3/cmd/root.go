package cmd

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/spf13/cobra"
)

var (
	VERSION string
)

func Execute(version string) {
	VERSION = version
	if err := rootCmd.Execute(); err != nil {
		log.Println(err)
		os.Exit(1)
	}
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println(rootCmd.Use + " " + VERSION)
	},
}

// Setup flags and make them required
func init() {
	rootCmd.AddCommand(versionCmd)
}

// Definition and usage of license-util binary
var rootCmd = &cobra.Command{
	Use:   "lutil3",
	Short: "Accept CPD Usage License",
	Run: func(cmd *cobra.Command, args []string) {
		resp := acceptLicense()
		if !resp {
			log.Println("License must be accepted to activate CloudPak for Data")
			os.Exit(1)
		}
		content := []byte("cpdlicense.accepted=true")
		err := ioutil.WriteFile("cpd.license", content, 0644)
		if err != nil {
			panic(err)
		}
		log.Println("License file generated")
	},
}
