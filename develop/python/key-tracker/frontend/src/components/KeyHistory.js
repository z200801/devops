import React, { useState, useEffect } from 'react';
import { Container, Table, Form, Alert, Button, Modal, InputGroup } from 'react-bootstrap';
import { useTranslation } from 'react-i18next';
import axios from 'axios';
import { formatDateTime } from '../utils/dateFormatter';

const API_URL = '/api';

const KeyHistory = () => {
  const { t } = useTranslation();
  const [history, setHistory] = useState([]);
  const [sites, setSites] = useState([]);
  const [selectedSite, setSelectedSite] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filterValue, setFilterValue] = useState('');
  const [isRegExp, setIsRegExp] = useState(false);
  
  // Стан для модального вікна редагування
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingEntry, setEditingEntry] = useState(null);
  const [editForm, setEditForm] = useState({
    issued_to: '',
    issued_at: '',
    returned_at: '',
    memo: ''
  });
  
  // Стан для модального вікна видалення
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletingEntry, setDeletingEntry] = useState(null);
  
  useEffect(() => {
    fetchSites();
    fetchHistory();
  }, []);
  
  useEffect(() => {
    fetchHistory(selectedSite);
  }, [selectedSite]);
  
  const fetchSites = async () => {
    try {
      const response = await axios.get(`${API_URL}/sites/`);
      setSites(response.data);
    } catch (err) {
      console.error('Error fetching sites:', err);
      setError(t('history.errorFetchingSites'));
    }
  };
  
  const fetchHistory = async (siteCode = '') => {
    try {
      setLoading(true);
      const url = siteCode 
        ? `${API_URL}/history/?site_code=${siteCode}` 
        : `${API_URL}/history/`;
      
      const response = await axios.get(url);
      
      // Отримати додаткову інформацію про ключі
      const keysResponse = await axios.get(`${API_URL}/keys/`);
      
      // Збагатити історію даними про ключі та об'єкти
      const historyWithDetails = await Promise.all(
        response.data.map(async (entry) => {
          const key = keysResponse.data.find(k => k.key_id === entry.key_id);
          
          return {
            ...entry,
            site_code: key ? key.site_code : t('history.unknownSite'),
            description: key ? key.description : t('history.unknownKey')
          };
        })
      );
      
      setHistory(historyWithDetails);
      setError(null);
    } catch (err) {
      console.error('Error fetching history:', err);
      setError(t('history.errorFetchingHistory'));
    } finally {
      setLoading(false);
    }
  };
  
  const handleSiteChange = (e) => {
    setSelectedSite(e.target.value);
  };
  
  const handleFilterChange = (e) => {
    setFilterValue(e.target.value);
  };
  
  const toggleRegExp = () => {
    setIsRegExp(!isRegExp);
  };
  
  // Функція фільтрації даних
  const getFilteredHistory = () => {
    if (!filterValue.trim()) return history;
    
    try {
      if (isRegExp) {
        const regex = new RegExp(filterValue, 'i');
        return history.filter(entry => 
          regex.test(entry.site_code) || 
          regex.test(entry.description) ||
          regex.test(entry.issued_to || '') ||
          regex.test(entry.memo || '')
        );
      } else {
        const lowercaseFilter = filterValue.toLowerCase();
        return history.filter(entry => 
          entry.site_code.toLowerCase().includes(lowercaseFilter) || 
          entry.description.toLowerCase().includes(lowercaseFilter) ||
          (entry.issued_to && entry.issued_to.toLowerCase().includes(lowercaseFilter)) ||
          (entry.memo && entry.memo.toLowerCase().includes(lowercaseFilter))
        );
      }
    } catch (err) {
      console.error('Error filtering history:', err);
      // У разі помилки в регулярному виразі показуємо всі дані
      return history;
    }
  };
  
  // Функція для відкриття модального вікна редагування
  const handleEditClick = (entry) => {
    setEditingEntry(entry);
    setEditForm({
      issued_to: entry.issued_to || '',
      issued_at: entry.issued_at ? new Date(entry.issued_at).toISOString().slice(0, 16) : '',
      returned_at: entry.returned_at ? new Date(entry.returned_at).toISOString().slice(0, 16) : '',
      memo: entry.memo || ''
    });
    setShowEditModal(true);
  };
  
  // Функція для відкриття модального вікна видалення
  const handleDeleteClick = (entry) => {
    setDeletingEntry(entry);
    setShowDeleteModal(true);
  };
  
  // Функція для видалення запису
  const handleConfirmDelete = async () => {
    if (!deletingEntry) return;
    
    try {
      setLoading(true);
      
      // Відправляємо запит на видалення
      await axios.delete(`${API_URL}/history/${deletingEntry.history_id}`);
      
      // Оновлюємо список після видалення
      fetchHistory(selectedSite);
      
      // Закриваємо модальне вікно
      setShowDeleteModal(false);
      setDeletingEntry(null);
      
    } catch (err) {
      console.error('Error deleting history entry:', err);
      setError(t('history.errorDeleting'));
    } finally {
      setLoading(false);
    }
  };
  
  // Функція для обробки змін у формі
  const handleEditFormChange = (e) => {
    const { name, value } = e.target;
    setEditForm({
      ...editForm,
      [name]: value
    });
  };
  
  // Функція для збереження змін
  const handleSaveEdit = async () => {
    try {
      setLoading(true);
      
      // Перевіряємо, які поля були змінені
      const updates = {};
      if (editForm.issued_to !== editingEntry.issued_to) updates.issued_to = editForm.issued_to;
      if (editForm.issued_at !== (editingEntry.issued_at ? new Date(editingEntry.issued_at).toISOString().slice(0, 16) : '')) 
        updates.issued_at = editForm.issued_at;
      if (editForm.returned_at !== (editingEntry.returned_at ? new Date(editingEntry.returned_at).toISOString().slice(0, 16) : ''))
        updates.returned_at = editForm.returned_at;
      if (editForm.memo !== editingEntry.memo) updates.memo = editForm.memo;
      
      // Якщо є зміни, відправляємо запит на сервер
      if (Object.keys(updates).length > 0) {
        await axios.put(`${API_URL}/history/${editingEntry.history_id}`, updates);
        // Оновлюємо список після збереження
        fetchHistory(selectedSite);
      }
      
      // Закриваємо модальне вікно
      setShowEditModal(false);
    } catch (err) {
      console.error('Error updating history entry:', err);
      setError(t('history.errorUpdating'));
    } finally {
      setLoading(false);
    }
  };
  
  const filteredHistory = getFilteredHistory();
  
  return (
    <Container>
      <h1 className="mb-4">{t('history.title')}</h1>
      
      <Form.Group className="mb-4">
        <Form.Label>{t('history.filterBySite')}</Form.Label>
        <Form.Select
          value={selectedSite}
          onChange={handleSiteChange}
        >
          <option value="">{t('history.allSites')}</option>
          {sites.map((site) => (
            <option key={site.site_id} value={site.site_code}>
              {site.site_code} - {site.address}
            </option>
          ))}
        </Form.Select>
      </Form.Group>
      
      <Form.Group className="mb-3">
        <InputGroup>
          <Form.Control
            type="text"
            placeholder={t('history.filter')}
            value={filterValue}
            onChange={handleFilterChange}
          />
          <InputGroup.Checkbox 
            label="RegExp"
            checked={isRegExp}
            onChange={toggleRegExp}
          />
          <InputGroup.Text>RegExp</InputGroup.Text>
        </InputGroup>
        <Form.Text className="text-muted">
          {isRegExp ? t('history.filterMode.regexp') : t('history.filterMode.simple')}
        </Form.Text>
      </Form.Group>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {loading ? (
        <p>{t('history.loading')}</p>
      ) : filteredHistory.length === 0 ? (
        <Alert variant="info">{t('history.noHistory')}</Alert>
      ) : (
        <Table striped bordered hover responsive>
          <thead>
            <tr>
              <th>{t('history.columns.id')}</th>
              <th>{t('history.columns.site')}</th>
              <th>{t('history.columns.description')}</th>
              <th>{t('history.columns.issuedTo')}</th>
              <th>{t('history.columns.issuedAt')}</th>
              <th>{t('history.columns.returnedAt')}</th>
              <th>{t('history.columns.notes')}</th>
              <th>{t('history.columns.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredHistory.map((entry) => (
              <tr key={entry.history_id}>
                <td>{entry.history_id}</td>
                <td>{entry.site_code}</td>
                <td>{entry.description}</td>
                <td>{entry.issued_to || '-'}</td>
                <td>{entry.issued_at ? formatDateTime(entry.issued_at) : '-'}</td>
                <td>
                  {entry.returned_at 
                    ? formatDateTime(entry.returned_at) 
                    : <span className="text-warning">{t('history.notReturned')}</span>}
                </td>
                <td>{entry.memo || '-'}</td>
                <td>
                  <div className="d-flex">
                    <Button 
                      variant="warning" 
                      size="sm"
                      className="me-2"
                      onClick={() => handleEditClick(entry)}
                    >
                      {t('history.actions.edit')}
                    </Button>
                    <Button 
                      variant="danger" 
                      size="sm"
                      onClick={() => handleDeleteClick(entry)}
                    >
                      {t('history.actions.delete')}
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
      
      {/* Модальне вікно для редагування */}
      <Modal show={showEditModal} onHide={() => setShowEditModal(false)}>
        <Modal.Header closeButton>
          <Modal.Title>{t('history.editModal.title')}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form>
            <Form.Group className="mb-3">
              <Form.Label>{t('history.editModal.issuedTo')}</Form.Label>
              <Form.Control 
                type="text" 
                name="issued_to" 
                value={editForm.issued_to} 
                onChange={handleEditFormChange} 
              />
            </Form.Group>
            <Form.Group className="mb-3">
              <Form.Label>{t('history.editModal.issuedAt')}</Form.Label>
              <Form.Control 
                type="datetime-local" 
                name="issued_at" 
                value={editForm.issued_at} 
                onChange={handleEditFormChange} 
              />
            </Form.Group>
            <Form.Group className="mb-3">
              <Form.Label>{t('history.editModal.returnedAt')}</Form.Label>
              <Form.Control 
                type="datetime-local" 
                name="returned_at" 
                value={editForm.returned_at} 
                onChange={handleEditFormChange} 
              />
            </Form.Group>
            <Form.Group className="mb-3">
              <Form.Label>{t('history.editModal.notes')}</Form.Label>
              <Form.Control 
                as="textarea" 
                rows={3} 
                name="memo" 
                value={editForm.memo} 
                onChange={handleEditFormChange} 
              />
            </Form.Group>
          </Form>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowEditModal(false)}>
            {t('history.editModal.cancel')}
          </Button>
          <Button variant="primary" onClick={handleSaveEdit} disabled={loading}>
            {loading ? t('history.editModal.saving') : t('history.editModal.save')}
          </Button>
        </Modal.Footer>
      </Modal>
      
      {/* Модальне вікно для підтвердження видалення */}
      <Modal show={showDeleteModal} onHide={() => setShowDeleteModal(false)}>
        <Modal.Header closeButton>
          <Modal.Title>{t('history.deleteModal.title')}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {deletingEntry && (
            <p>
              {t('history.deleteModal.message', {
                historyId: deletingEntry.history_id,
                description: deletingEntry.description,
                siteCode: deletingEntry.site_code
              })}
            </p>
          )}
          <p className="text-danger">{t('history.deleteModal.warning')}</p>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowDeleteModal(false)}>
            {t('history.deleteModal.cancel')}
          </Button>
          <Button variant="danger" onClick={handleConfirmDelete} disabled={loading}>
            {loading ? t('history.deleteModal.deleting') : t('history.deleteModal.delete')}
          </Button>
        </Modal.Footer>
      </Modal>
    </Container>
  );
};

export default KeyHistory;

