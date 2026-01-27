#!/usr/bin/env bash

# Copyright 2026 The Kubeflow Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
SCRIPT_ROOT="$(realpath "${SCRIPT_DIR}/../..")"
SPARK_OPERATOR_PKG="github.com/kubeflow/spark-operator/v2"

# Get the kube-openapi binary to generate OpenAPI spec.
OPENAPI_PKG=$(go list -m -mod=readonly -f "{{.Dir}}" k8s.io/kube-openapi)
echo ">> Using ${OPENAPI_PKG}"

# This list needs to cover all types used transitively from the Spark Operator APIs.
# Update this list if Spark Operator depends on new external APIs.
EXTRA_PACKAGES=(
  k8s.io/apimachinery/pkg/apis/meta/v1
  k8s.io/apimachinery/pkg/api/resource
  k8s.io/apimachinery/pkg/runtime
  k8s.io/apimachinery/pkg/util/intstr
  k8s.io/api/core/v1
  k8s.io/api/batch/v1
)

# Generate OpenAPI Go code for each API version
for VERSION in v1alpha1 v1beta2; do
  echo "Generating OpenAPI for ${VERSION}"

  go run ${OPENAPI_PKG}/cmd/openapi-gen \
    --go-header-file "${SCRIPT_ROOT}/hack/boilerplate.go.txt" \
    --output-pkg "${SPARK_OPERATOR_PKG}/api/${VERSION}" \
    --output-dir "${SCRIPT_ROOT}/api/${VERSION}" \
    --output-file "zz_generated.openapi.go" \
    "${EXTRA_PACKAGES[@]}" \
    "${SCRIPT_ROOT}/api/${VERSION}"
done

# Create output directory for swagger spec
mkdir -p "${SCRIPT_ROOT}/api/openapi-spec"

# Generate combined OpenAPI Swagger JSON (imports both v1alpha1 and v1beta2)
echo "Generating OpenAPI Swagger for Kubeflow Spark Operator"
go run "${SCRIPT_ROOT}/hack/swagger/main.go" > "${SCRIPT_ROOT}/api/openapi-spec/swagger.json"

echo "OpenAPI generation complete!"
echo "  - api/v1alpha1/zz_generated.openapi.go"
echo "  - api/v1beta2/zz_generated.openapi.go"
echo "  - api/openapi-spec/swagger.json"
