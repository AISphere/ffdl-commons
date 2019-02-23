/*
 * Copyright 2017-2018 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package main

import (
	"net"
	"os"
	"os/exec"
	"syscall"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
)

const Cli = "./bin/grpc-health-checker"

func TestServing(t *testing.T) {
	t.Skip("Skipping TestServing for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(false)
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port)
	cmd.Dir = dir

	if err := cmd.Run(); err != nil {
		t.Fatal(err)
	}
}

func TestServingTLS(t *testing.T) {
	t.Skip("Skipping TestServingTLS for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(true)
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port, "--tls", "--cacert", "./testdata/ca.crt")
	cmd.Dir = dir
	if err := cmd.Run(); err != nil {
		t.Fatal(err)
	}

}

func TestServingNonTLSClient(t *testing.T) {
	t.Skip("Skipping TestServingNonTLSClient for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(true) // we service TLS but don't connect tls
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port) // no tls used
	cmd.Dir = dir
	if err := cmd.Run(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			// The program has exited with an exit code != 0

			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				if status.ExitStatus() != 1 {
					t.Fatal("Exit status != 1: ", status.ExitStatus())
				}
			}
		} else {
			t.Fatalf("cmd.Wait: %v", err)
		}
	}
}

func TestServingNonTLSServer(t *testing.T) {
	t.Skip("Skipping TestServingNonTLSServer for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(true) // we do not service TLS but connect tls
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port, "--tls", "--cacert", "./testdata/ca.crt")
	cmd.Dir = dir
	if err := cmd.Run(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			// The program has exited with an exit code != 0

			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				if status.ExitStatus() != 1 {
					t.Fatal("Exit status != 1: ", status.ExitStatus())
				}
			}
		} else {
			t.Fatalf("cmd.Wait: %v", err)
		}
	}
}

func TestServingTLSWrongHostname(t *testing.T) {
	t.Skip("Skipping TestServingTLSWrongHostname for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(true)
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port, "--tls", "--cacert", "./testdata/ca.crt", "--caname", "foobar")
	cmd.Dir = dir
	if err := cmd.Run(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			// The program has exited with an exit code != 0

			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				if status.ExitStatus() != 1 {
					t.Fatal("Exit status != 1: ", status.ExitStatus())
				}
			}
		} else {
			t.Fatalf("cmd.Wait: %v", err)
		}
	}
}

func TestNotServing(t *testing.T) {
	t.Skip("Skipping TestNotServing for now (needs fixing)")
	checkBinary(t)

	hep := newHealthEndpoint(false)
	hep.startHealthEndpoint(t)
	defer hep.stopHealthEndpoint(t)
	hep.setHealthStatus("foobar.service", grpc_health_v1.HealthCheckResponse_NOT_SERVING)

	// get host and dynamic port of the listener
	host, port, _ := net.SplitHostPort(hep.listener.Addr().String())

	dir, _ := os.Getwd()
	cmd := exec.Command("./bin/grpc-health-checker", "--host", host, "--port", port, "-s", "foobar.service")
	cmd.Dir = dir

	if err := cmd.Run(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			// The program has exited with an exit code != 0

			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				if status.ExitStatus() != 3 {
					t.Fatal("Exit status != 3: ", status.ExitStatus())
				}
			}
		} else {
			t.Fatalf("cmd.Wait: %v", err)
		}
	}
}

// Helper functions

func checkBinary(t *testing.T) {
	if _, err := os.Stat(Cli); err != nil {
		t.Fatalf("CLI binary does not exist. Please call 'make build-local' before running the tests")
	}
}

type healthEndpoint struct {
	tls          bool
	listener     net.Listener
	server       *grpc.Server
	healthServer *health.Server
}

func newHealthEndpoint(tls bool) *healthEndpoint {
	return &healthEndpoint{
		tls:          tls,
		healthServer: health.NewServer(),
	}
}

func (h *healthEndpoint) startHealthEndpoint(t *testing.T) {
	lis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to listen: %v", err)
	}

	var opts []grpc.ServerOption
	if h.tls {
		creds, err := credentials.NewServerTLSFromFile("./testdata/server.crt", "./testdata/server.key")
		if err != nil {
			t.Fatalf("Failed to generate credentials %v", err)
		}
		opts = []grpc.ServerOption{grpc.Creds(creds)}
	}

	s := grpc.NewServer(opts...)
	grpc_health_v1.RegisterHealthServer(s, h.healthServer)
	go s.Serve(lis)

	h.listener = lis
	h.server = s
}

func (h *healthEndpoint) stopHealthEndpoint(t *testing.T) {
	if h.listener != nil {
		if err := h.listener.Close(); err != nil {
			t.Fatal(err)
		}
	}
	if h.server != nil {
		h.server.Stop()
	}
}

func (h *healthEndpoint) setHealthStatus(service string, status grpc_health_v1.HealthCheckResponse_ServingStatus) {
	h.healthServer.SetServingStatus(service, status)
}
