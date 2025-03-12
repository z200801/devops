import React, { useState } from 'react';
import { Container, Card, Button, Alert, Form, Modal } from 'react-bootstrap';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const BackupRestore = () => {
  const { t } = useTranslation();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  const [uploadFile, setUploadFile] = useState(null);
  const [showClearModal, setShowClearModal] = useState(false);
  
  const handleDownloadBackup = async () => {
    try {
      setLoading(true);
      setError(null);
      
      // Використовуємо axios для отримання файлу
      const response = await axios.get(`${API_URL}/backup/`, {
        responseType: 'blob', // Важливо для файлів
      });
      
      // Створюємо URL для завантаження
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      
      // Отримання імені файлу з заголовків або використання стандартного
      const contentDisposition = response.headers['content-disposition'];
      let filename = 'key_tracker_backup.yaml';
      
      if (contentDisposition) {
        const filenameMatch = contentDisposition.match(/filename="(.+)"/);
        if (filenameMatch && filenameMatch.length === 2) {
          filename = filenameMatch[1];
        }
      }
      
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      setSuccessMessage(t('backup.success'));
    } catch (err) {
      console.error('Error downloading backup:', err);
      setError(t('backup.error'));
    } finally {
      setLoading(false);
    }
  };
  
  const handleFileChange = (e) => {
    setUploadFile(e.target.files[0]);
  };
  
  const handleRestore = async (e) => {
    e.preventDefault();
    
    if (!uploadFile) {
      setError(t('backup.selectFileError'));
      return;
    }
    
    // Перевірка типу файлу (хоча б базова)
    if (!uploadFile.name.endsWith('.yaml') && !uploadFile.name.endsWith('.yml')) {
      setError(t('backup.invalidFileType'));
      return;
    }
    
    try {
      setLoading(true);
      setError(null);
      
      // Створюємо FormData для відправки файлу
      const formData = new FormData();
      formData.append('file', uploadFile);
      
      // Відправляємо запит на відновлення
      await axios.post(`${API_URL}/backup/restore/`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      setSuccessMessage(t('backup.restoreSuccess'));
      setUploadFile(null);
      
      // Скидаємо поле вибору файлу
      const fileInput = document.getElementById('backup-file');
      if (fileInput) {
        fileInput.value = '';
      }
    } catch (err) {
      console.error('Error restoring backup:', err);
      setError(t('backup.restoreError'));
    } finally {
      setLoading(false);
    }
  };
  
  const handleClearDatabase = async () => {
    try {
      setLoading(true);
      setError(null);
      
      // Відправляємо запит на очищення бази даних
      await axios.delete(`${API_URL}/backup/clear/`);
      
      setSuccessMessage(t('backup.clearSuccess'));
      setShowClearModal(false);
    } catch (err) {
      console.error('Error clearing database:', err);
      setError(t('backup.clearError'));
    } finally {
      setLoading(false);
    }
  };
  
  // Функція для закриття повідомлень
  const clearMessages = () => {
    setError(null);
    setSuccessMessage(null);
  };
  
  return (
    <Container>
      <h1 className="mb-4">{t('backup.title')}</h1>
      
      {error && (
        <Alert variant="danger" dismissible onClose={clearMessages}>
          {error}
        </Alert>
      )}
      
      {successMessage && (
        <Alert variant="success" dismissible onClose={clearMessages}>
          {successMessage}
        </Alert>
      )}
      
      <div className="row">
        <div className="col-md-6 mb-4">
          <Card>
            <Card.Body>
              <Card.Title>{t('backup.backupCard.title')}</Card.Title>
              <Card.Text>
                {t('backup.backupCard.description')}
              </Card.Text>
              <Button 
                variant="primary" 
                onClick={handleDownloadBackup}
                disabled={loading}
              >
                {loading ? t('backup.backupCard.creating') : t('backup.backupCard.button')}
              </Button>
            </Card.Body>
          </Card>
        </div>
        
        <div className="col-md-6 mb-4">
          <Card>
            <Card.Body>
              <Card.Title>{t('backup.restoreCard.title')}</Card.Title>
              <Card.Text>
                {t('backup.restoreCard.description')}
                <strong className="text-danger"> {t('backup.restoreCard.warning')}</strong>
              </Card.Text>
              <Form onSubmit={handleRestore}>
                <Form.Group controlId="backup-file" className="mb-3">
                  <Form.Control 
                    type="file" 
                    onChange={handleFileChange}
                    accept=".yaml,.yml"
                  />
                  <Form.Text className="text-muted">
                    {t('backup.restoreCard.selectFile')}
                  </Form.Text>
                </Form.Group>
                <Button 
                  variant="warning" 
                  type="submit"
                  disabled={loading || !uploadFile}
                >
                  {loading ? t('backup.restoreCard.restoring') : t('backup.restoreCard.button')}
                </Button>
              </Form>
            </Card.Body>
          </Card>
        </div>
      </div>
      
      <Card className="mb-4 border-danger">
        <Card.Body>
          <Card.Title className="text-danger">{t('backup.clearDatabase.title')}</Card.Title>
          <Card.Text>
            {t('backup.clearDatabase.description')}
          </Card.Text>
          <Button 
            variant="danger" 
            onClick={() => setShowClearModal(true)}
          >
            {t('backup.clearDatabase.button')}
          </Button>
        </Card.Body>
      </Card>
      
      {/* Модальне вікно для підтвердження очищення бази даних */}
      <Modal show={showClearModal} onHide={() => setShowClearModal(false)}>
        <Modal.Header closeButton>
          <Modal.Title className="text-danger">{t('backup.clearModal.title')}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p><strong>{t('backup.clearModal.warning')}</strong></p>
          <p>{t('backup.clearModal.message')}</p>
          <ul>
            <li>{t('backup.clearModal.items.sites')}</li>
            <li>{t('backup.clearModal.items.keys')}</li>
            <li>{t('backup.clearModal.items.history')}</li>
          </ul>
          <p>{t('backup.clearModal.confirmation')}</p>
          <p>{t('backup.clearModal.question')}</p>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowClearModal(false)}>
            {t('backup.clearModal.cancel')}
          </Button>
          <Button 
            variant="danger" 
            onClick={handleClearDatabase}
            disabled={loading}
          >
            {loading ? t('backup.clearModal.clearing') : t('backup.clearModal.confirm')}
          </Button>
        </Modal.Footer>
      </Modal>
    </Container>
  );
};

export default BackupRestore;

