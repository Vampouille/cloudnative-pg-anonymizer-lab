<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Kubernetes Access Cards</title>
  <style>
${css}  </style>
  <script>${pagedjs}</script>
</head>
<body>
  <div class="grid">
%{ for u in users ~}
    <div class="card">
      <div class="card-title">Workshop Access</div>
      <div class="field">
        <span class="label">URL</span>
        <span class="value">${u.username}.${domain}</span>
      </div>
      <div class="field">
        <span class="label">User</span>
        <span class="value">${u.username}</span>
      </div>
      <div class="field">
        <span class="label">Password</span>
        <span class="value">${u.password}</span>
      </div>
      <div class="footer-title">Contact</div>
      <div class="email">alain.lesage@dalibo.com</div>
      <div class="email">julien.acroute@camptocamp.com</div>
    </div>
%{ endfor ~}
  </div>
</body>
</html>
