package main

import (
	"context"
	"fmt"
	opnode "github.com/ethereum-optimism/optimism/op-node"
	"github.com/ethereum-optimism/optimism/op-node/chaincfg"
	"github.com/ethereum-optimism/optimism/op-node/cmd/genesis"
	"github.com/ethereum-optimism/optimism/op-node/flags"
	metrics "github.com/ethereum-optimism/optimism/op-node/metrics"
	node "github.com/ethereum-optimism/optimism/op-node/node"
	opservice "github.com/ethereum-optimism/optimism/op-service"
	"github.com/ethereum-optimism/optimism/op-service/cliapp"
	"github.com/ethereum-optimism/optimism/op-service/ctxinterrupt"
	oplog "github.com/ethereum-optimism/optimism/op-service/log"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"
	"os"
)

var VersionWithMeta = "0.0.1"

func main() {
	// Set up logger with a default INFO level in case we fail to parse flags,
	// otherwise the final critical log won't show what the parsing error was.
	oplog.SetupDefaults()

	app := cli.NewApp()
	app.Version = VersionWithMeta
	app.Flags = cliapp.ProtectFlags(flags.Flags)
	app.Name = "op-node"
	app.Usage = "Optimism Rollup Node"
	app.Description = "The Optimism Rollup Node derives L2 block inputs from L1 data and drives an external L2 Execution Engine to build a L2 chain."
	app.Action = cliapp.LifecycleCmd(RollupNodeMain)
	app.Commands = []*cli.Command{
		{
			Name:        "genesis",
			Subcommands: genesis.Subcommands,
		},
	}

	ctx := ctxinterrupt.WithSignalWaiterMain(context.Background())
	err := app.RunContext(ctx, os.Args)
	if err != nil {
		log.Crit("Application failed", "message", err)
	}
}

func RollupNodeMain(ctx *cli.Context, closeApp context.CancelCauseFunc) (cliapp.Lifecycle, error) {
	logCfg := oplog.ReadCLIConfig(ctx)
	log := oplog.NewLogger(oplog.AppOut(ctx), logCfg)
	oplog.SetGlobalLogHandler(log.Handler())
	opservice.ValidateEnvVars(flags.EnvVarPrefix, flags.Flags, log)
	opservice.WarnOnDeprecatedFlags(ctx, flags.DeprecatedFlags, log)

	cfg, err := opnode.NewConfig(ctx, log)
	if err != nil {
		return nil, fmt.Errorf("unable to create the rollup node config: %w", err)
	}
	cfg.Cancel = closeApp

	// Only pretty-print the banner if it is a terminal log. Other log it as key-value pairs.
	if logCfg.Format == "terminal" {
		log.Info("rollup config:\n" + cfg.Rollup.Description(chaincfg.L2ChainIDToNetworkDisplayName))
	} else {
		cfg.Rollup.LogDescription(log, chaincfg.L2ChainIDToNetworkDisplayName)
	}

	// Create a mock metrics instance
	mockMetrics := metrics.NewMetrics("default")

	n, err := node.New(ctx.Context, cfg, log, VersionWithMeta, mockMetrics)
	if err != nil {
		return nil, fmt.Errorf("unable to create the rollup node: %w", err)
	}

	return n, nil
}
