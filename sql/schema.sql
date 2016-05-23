CREATE TABLE `vms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `requested_on` datetime NOT NULL,
  `created_on` datetime DEFAULT NULL,
  `expires_on` datetime DEFAULT NULL,
  `destroyed_on` datetime DEFAULT NULL,
  `request_email` varchar(200) DEFAULT NULL,
  `request_ip_address` varchar(50) DEFAULT NULL,
  `request_language` varchar(8) DEFAULT NULL,
  `request_application` varchar(16) DEFAULT NULL,
  `symbol` varchar(50) DEFAULT NULL,
  `hostname` varchar(200) DEFAULT NULL,
  `ip_address` varchar(39) DEFAULT NULL,
  `data` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1
