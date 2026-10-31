# Releasing the chart

Publish reviewed chart packages manually. Each chart version identifies immutable contents. Publishing does not upgrade running installations.

## Prepare the release

The source repository is [eddie-energy/eddie-helm](https://github.com/eddie-energy/eddie-helm). The source installation is documented in [the chart guide](chart/README.md). OCI distribution is optional. Choose the registry and namespace before publishing a package, then announce the complete chart reference after verifying retrieval.

`chart/Chart.yaml: version` is the package version. Use a patch for compatible fixes, a minor for compatible additions, and a major for incompatible configuration or deployment changes. `appVersion` describes EDDIE and stays aligned with the configured core image.

Update the chart version, root README version marker, packaged version reference, change log, and versioned examples together. Use plain SemVer such as `1.3.0`. Never replace a published package or move its release tag.

Confirm application and dependency compatibility, licences, notices, and image availability. HiveMQ requires access to its separate extension image or an accessible compatible image.

## Validate and package

Use a clean checkout of the reviewed release commit. From the repository root:

```sh
git status --short
helm dependency build ./chart
python -m pip install -r test/requirements.txt
python -m unittest discover -s test -v
helm lint ./chart --strict -f chart/examples/values.internal.yaml
helm lint ./chart --strict -f chart/examples/values.public.yaml
helm lint ./chart --strict -f chart/examples/values.internal.yaml --set mqtt.broker=hivemq
helm lint ./chart --strict -f chart/examples/values.internal.yaml --set strimziOperator.enabled=true
helm lint ./chart --strict -f chart/examples/values.kafka-external.yaml
helm lint ./chart --strict -f chart/examples/values.internal.yaml -f chart/examples/values.migration-options.yaml
helm template eddie ./chart -n eddie -f chart/examples/values.internal.yaml > rendered.local.yaml
mkdir -p dist
helm package ./chart --destination dist
tar -tzf dist/eddie-1.3.0.tgz
```

Review the rendered resources and archive contents. Include the dependency, licence, notices, examples, release notes, and connector documentation. Keep private values, rendered Secrets, keys, and registry credentials outside the package.

Helm linting and rendering assess chart output. Verify image retrieval and the intended database and application flows separately before accepting the release.

Record the reviewed source commit with an annotated or signed tag:

```sh
git show HEAD:chart/Chart.yaml
git tag -a chart-v1.3.0 HEAD -m "EDDIE chart 1.3.0"
git push origin refs/tags/chart-v1.3.0
```

Confirm that the tag, package filename, and chart metadata contain the selected version. The tag records the source commit and does not publish the package.

## Publish to a chosen registry

Replace the example host and namespace below with the registry selected for distribution. These are placeholders, not an existing chart package location:

```sh
REGISTRY_HOST="registry.example.org"
REGISTRY_NAMESPACE="oci://registry.example.org/organisation/charts"
CHART_REF="$REGISTRY_NAMESPACE/eddie"
helm registry login "$REGISTRY_HOST"
```

Use credentials with permission to publish to that namespace. Before pushing, check that the version is absent. This Bash block permits publication only when the registry explicitly reports a missing manifest. An existing version, authentication failure, connectivity failure, or unrecognised response stops publication:

```sh
ERROR_FILE="$(mktemp)"
if helm show chart "$CHART_REF" --version 1.3.0 >/dev/null 2>"$ERROR_FILE"; then
  printf 'Version 1.3.0 already exists. Select a new chart version.\n' >&2
  rm "$ERROR_FILE"
  false
elif grep -Eqi 'manifest unknown|MANIFEST_UNKNOWN' "$ERROR_FILE"; then
  rm "$ERROR_FILE"
  helm push dist/eddie-1.3.0.tgz "$REGISTRY_NAMESPACE"
else
  cat "$ERROR_FILE" >&2
  rm "$ERROR_FILE"
  false
fi
```

If the registry uses a different missing manifest response, verify absence through its own interface before publishing. Other errors do not establish that a version is available to use. Coordinate publication so that two people do not publish the same version concurrently, and configure registry version immutability when available.

The destination of `helm push` omits the chart name and tag because Helm reads both from the package. See [Helm's OCI registry guidance](https://helm.sh/docs/topics/registries/). Configure public package access before announcing an anonymous download location.

## Verify retrieval

After publishing, use the actual `CHART_REF` with a clean Helm registry configuration to confirm anonymous access:

```sh
REGISTRY_CONFIG="$(mktemp)"
printf '{"auths":{}}\n' > "$REGISTRY_CONFIG"
helm show chart "$CHART_REF" --version 1.3.0 --registry-config "$REGISTRY_CONFIG"
helm show readme "$CHART_REF" --version 1.3.0 --registry-config "$REGISTRY_CONFIG"
rm "$REGISTRY_CONFIG"
```

Download and inspect the published package. Record the registry digest and verification outcome. Confirm anonymous retrieval of images advertised as public. Document and verify registry credentials for optional private images.

If publication fails, first check whether the package now exists. Correct access or connectivity before retrying. Source changes require a new chart version. Never overwrite an existing release to correct its contents.

Operators select a published version and private values when upgrading an installation. Read the release notes, back up data, and review a rendered resource diff first. Repeat application verification afterwards. Helm rollback does not reverse database schema changes or restore volume contents.
