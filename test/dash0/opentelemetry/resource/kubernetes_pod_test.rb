# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module Resource
      class KubernetesPodTest < Minitest::Test
        include TestHelpers

        POD_UID = 'e462ffed-94ce-4806-a52e-d2726f448f15'

        # The detector's only public method is `detect`; the pure parsers below are
        # internal and exercised via `send`.

        def test_kubernetes_managed_hosts_detection
          assert KubernetesPod.send(:kubernetes_managed_hosts?, "# Kubernetes-managed hosts file\n127.0.0.1 localhost")
          refute KubernetesPod.send(:kubernetes_managed_hosts?, "127.0.0.1 localhost\n")
          refute KubernetesPod.send(:kubernetes_managed_hosts?, '')
          refute KubernetesPod.send(:kubernetes_managed_hosts?, nil)
        end

        def test_cgroup_v1_pod_uid_from_mountinfo
          line = "2748 2737 0:63 /var/lib/kubelet/pods/#{POD_UID}/etc-hosts /etc/hosts " \
                 'rw,relatime master:1 - ext4 /dev/sda1 rw'
          lines = KubernetesPod.send(:candidate_lines, line, KubernetesPod::POD_UID_CHARS)

          assert_equal POD_UID, KubernetesPod.send(:pod_uid_from_cgroup_v1, lines)
        end

        def test_cgroup_v1_returns_nil_without_pods_marker
          lines = KubernetesPod.send(:candidate_lines, '2748 2737 0:63 / /proc/acpi ro,relatime - tmpfs tmpfs ro', 0)

          assert_nil KubernetesPod.send(:pod_uid_from_cgroup_v1, lines)
        end

        def test_cgroup_v2_pod_uid_from_pod_prefixed_segment
          # penultimate segment "pod<uid>" (uid with hyphens), i.e. "pod" + 36 chars
          line = "0::/kubepods/pod#{POD_UID}/#{'a' * 64}"
          lines = KubernetesPod.send(:candidate_lines, line, KubernetesPod::CONTAINER_ID_CHARS)

          assert_equal POD_UID, KubernetesPod.send(:pod_uid_from_cgroup_v2, lines)
        end

        def test_cgroup_v2_pod_uid_from_slice_segment_normalizes_underscores
          slice = "kubepods-besteffort-pod#{POD_UID.tr('-', '_')}.slice"
          line = "0::/kubepods.slice/kubepods-besteffort.slice/#{slice}/#{'b' * 64}"
          lines = KubernetesPod.send(:candidate_lines, line, KubernetesPod::CONTAINER_ID_CHARS)

          assert_equal POD_UID, KubernetesPod.send(:pod_uid_from_cgroup_v2, lines)
        end

        def test_detect_returns_empty_resource_when_not_kubernetes
          # No /etc/hosts marker on the developer/CI machine → empty resource.
          result = run_in_subprocess do
            require 'opentelemetry-sdk'
            require 'dash0/opentelemetry'
            Dash0::OpenTelemetry::Resource::KubernetesPod.detect.instance_variable_get(:@attributes)
          end

          refute result[:error], result[:error]
          refute result.key?('k8s.pod.uid')
        end
      end
    end
  end
end
