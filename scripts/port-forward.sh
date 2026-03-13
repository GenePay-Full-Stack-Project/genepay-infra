#!/bin/bash
echo "Starting port forwarding for GenePay services..."

H="127.0.0.1"

echo "Forwarding PostgreSQL to $H:5432..."
kubectl port-forward -n genepay svc/postgres 5432:5432 &
KUBECTL_PIDS+=($!)

echo "Forwarding Biometric Service to $H:8001..."
kubectl port-forward -n genepay svc/biometric-service 8001:8001 &
KUBECTL_PIDS+=($!)

echo "Forwarding Blockchain Relay to $H:3001..."
kubectl port-forward -n genepay svc/blockchain-relay 3001:3001 &
KUBECTL_PIDS+=($!)

echo "Forwarding Payment Service to $H:8080..."
kubectl port-forward -n genepay svc/payment-service 8080:8080 &
KUBECTL_PIDS+=($!)

echo "Forwarding Admin Dashboard to $H:3000..."
kubectl port-forward -n genepay svc/admin-dashboard 3000:80 &
KUBECTL_PIDS+=($!)

echo "Forwarding Blockchain Dashboard to $H:3002..."
kubectl port-forward -n genepay svc/blockchain-dashboard 3002:80 &
KUBECTL_PIDS+=($!)

echo "=========================================================="
echo "Port forwarding started in the background."
echo "PostgreSQL:           $H:5432"
echo "Biometric Service:    $H:8001"
echo "Blockchain Relay:     $H:3001"
echo "Payment Service:      $H:8080"
echo "Admin Dashboard:      $H:3000"
echo "Blockchain Dashboard: $H:3002"
echo "=========================================================="
echo "Press Ctrl+C to stop all port-forwarding."

# Clean up background processes on Ctrl+C
trap "echo -e '\nStopping port-forwarding...'; kill ${KUBECTL_PIDS[@]} 2>/dev/null; exit" SIGINT SIGTERM

# Wait indefinitely until interrupted
wait
