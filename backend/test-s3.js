const AWS = require('aws-sdk');
const fs = require('fs');
require('dotenv').config();

// Configuration AWS
AWS.config.update({
  region: process.env.AWS_REGION,
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

const s3 = new AWS.S3();
const BUCKET_NAME = process.env.S3_BUCKET_NAME;

async function testS3() {
  console.log('🧪 Test de connexion S3...');
  console.log('Bucket:', BUCKET_NAME);
  console.log('Region:', process.env.AWS_REGION);
  
  try {
    // Test 1 : Lister les objets du bucket
    console.log('\n1️⃣ Test: Lister le contenu du bucket...');
    const listResult = await s3.listObjectsV2({
      Bucket: BUCKET_NAME,
      MaxKeys: 10
    }).promise();
    
    console.log(`✅ Bucket accessible ! Objets: ${listResult.Contents.length}`);
    
    // Test 2 : Upload un fichier test
    console.log('\n2️⃣ Test: Upload fichier test...');
    const testContent = `Test S3 Upload - ${new Date().toISOString()}`;
    const uploadParams = {
      Bucket: BUCKET_NAME,
      Key: 'test/test-upload.txt',
      Body: testContent,
      ContentType: 'text/plain'
    };
    
    const uploadResult = await s3.upload(uploadParams).promise();
    console.log(`✅ Upload réussi !`);
    console.log(`URL: ${uploadResult.Location}`);
    
    // Test 3 : Télécharger le fichier
    console.log('\n3️⃣ Test: Download fichier...');
    const downloadParams = {
      Bucket: BUCKET_NAME,
      Key: 'test/test-upload.txt'
    };
    
    const downloadResult = await s3.getObject(downloadParams).promise();
    console.log(`✅ Download réussi !`);
    console.log(`Contenu: ${downloadResult.Body.toString()}`);
    
    // Test 4 : Supprimer le fichier test
    console.log('\n4️⃣ Test: Suppression fichier test...');
    await s3.deleteObject({
      Bucket: BUCKET_NAME,
      Key: 'test/test-upload.txt'
    }).promise();
    console.log(`✅ Fichier supprimé !`);
    
    console.log('\n🎉 Tous les tests S3 réussis !');
    
  } catch (error) {
    console.error('\n❌ Erreur S3:');
    console.error('Code:', error.code);
    console.error('Message:', error.message);
    
    if (error.code === 'NoSuchBucket') {
      console.log('\n💡 Le bucket n\'existe pas. Vérifiez le nom.');
    } else if (error.code === 'InvalidAccessKeyId') {
      console.log('\n💡 Access Key invalide. Vérifiez AWS_ACCESS_KEY_ID.');
    } else if (error.code === 'SignatureDoesNotMatch') {
      console.log('\n💡 Secret Key invalide. Vérifiez AWS_SECRET_ACCESS_KEY.');
    } else if (error.code === 'AccessDenied') {
      console.log('\n💡 Permissions insuffisantes. Vérifiez la Policy IAM.');
    }
  }
}

testS3();