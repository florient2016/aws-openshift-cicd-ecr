# Supply-chain gate (natif, sans opérateur) : refuse toute image hors de notre ECR.
# Requiert OCP >= 4.17 (VAP GA). Sur 4.16, remplacer v1 par v1beta1.
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: only-itssolutions-ecr
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: >
        object.spec.containers.all(c, c.image.startsWith("${registry}/")) &&
        (!has(object.spec.initContainers) ||
         object.spec.initContainers.all(c, c.image.startsWith("${registry}/")))
      message: "Image refusée : seules les images de ${registry}/ sont autorisées (supply-chain itssolutions)."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: only-itssolutions-ecr-binding
spec:
  policyName: only-itssolutions-ecr
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        supply-chain: enforced
