
# Selecting provider who provide the cloud service

provider "aws" {
  region = "ap-south-1"
  profile = "ishprofile"
}

# Creating the instance of EC2 under free-tier usage

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "secondkey"
  security_groups = [ "launch-wizard-2" ]

  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/ManishVerma/Desktop/Hybrid/secondkey.pem")
    host = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git python3 -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }

  tags = {
    Name = "TestOS"
  }
}

# Creating the addition volume to make a persistent storage of data stored in instance

resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web.availability_zone
  size = 1

  tags = {
    Name = "Volume1"

  }
  depends_on = [
    aws_instance.web,
  ]

}

# Attaching the volume to the instance

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdz"
  volume_id = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.web.id
  force_detach = true 

  depends_on = [
    aws_ebs_volume.ebs1,
  ]
}

# Login to the instance using SSH protocol for mountung the volume and storing the important data

resource "null_resource" "remoteos" {

  depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  connection {
    type  = "ssh"
    user  = "ec2-user"
    private_key = file("C:/Users/ManishVerma/Desktop/Hybrid/secondkey.pem")
    host = aws_instance.web.public_ip

  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdz",
      "sudo mount /dev/xvdz /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/ManishVerma16/cloudtask1.git /var/www/html/"
    ]
  }

}

# Creating the S3 bucket for object storage

resource "aws_s3_bucket" "testbucket0012" {
  bucket = "testbucket0012"
  acl    = "public-read"   #private

  tags = {
    Name        = "testbucket0012"
    Environment = "Dev"
  }

  depends_on = [
    null_resource.remoteos
  ]
}

# Uploading an image to the S3 bucket

resource "aws_s3_bucket_object" "image" {
  bucket = aws_s3_bucket.testbucket0012.id
  key    = "aws_terraform.jpg"
  source = "C:/Users/ManishVerma/Desktop/Terra/cloudtask1/aws_terraform.jpg"
  acl = "public-read"
  content_type = "image or jpg"
  etag = filemd5("C:/Users/ManishVerma/Desktop/Terra/cloudtask1/aws_terraform.jpg")

  depends_on = [
    aws_s3_bucket.testbucket0012
  ]

}

# Creating Cloud Front Distribution for providing S3 objects

locals {
  s3_origin_id = "testbucket0012-id"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "CloudFront"
}


resource "aws_cloudfront_distribution" "s3-distribution" {
  
  # Setting up origin for Clount Front
  origin {
    domain_name = aws_s3_bucket.testbucket0012.bucket_regional_domain_name
    origin_id   =   local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled = true            # Allowed origin

  # Setting up default behaviour for Cloud Front

  default_cache_behavior {
    allowed_methods  = [ "GET", "HEAD" ]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Restriction has been made
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "IN"]
    }
  }

  # Tagging 

  tags = {
    Environment = "TestingEnv"
  }

  # SSL certificate allocation

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  price_class = "PriceClass_All"
}

resource "null_resource" "windows1"  {

  depends_on = [
    null_resource.windows,
  ]

	provisioner "local-exec" {
	    command = "firefox  ${aws_instance.web.public_ip}/firstpage.html"
  	}
}



resource "null_resource" "windows"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}

  depends_on = [
    aws_s3_bucket_object.image
  ]
}

# output "bucket_op" {
#   value = [ aws_s3_bucket.testbucket0012, aws_s3_bucket_object.image ]
# }


# output "avail-zone" {
#   value = aws_instance.web.availability_zone
# }

# output "volume_id" {
#   value = aws_ebs_volume.ebs1
# }


# resource "aws_s3_bucket_public_access_block" "access" {
#   bucket = "${aws_s3_bucket.bucket.id}"

#   block_public_acls   = false
#   block_public_policy = false
# }
