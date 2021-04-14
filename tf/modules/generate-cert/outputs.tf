output ca_cert_pem {

  value = tls_self_signed_cert.ca.cert_pem
}

output cert_private_key {

  value = tls_private_key.cert.private_key_pem
}

output cert_public_key {

  value = tls_locally_signed_cert.cert.cert_pem
}