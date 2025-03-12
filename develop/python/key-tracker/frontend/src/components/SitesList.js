import React, { useState, useEffect } from 'react';
import { Container, Table, Button, Alert, Form, InputGroup } from 'react-bootstrap';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const SitesList = () => {
  const { t } = useTranslation();
  const [sites, setSites] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filterValue, setFilterValue] = useState('');
  const [isRegExp, setIsRegExp] = useState(false);
  
  useEffect(() => {
    fetchSites();
  }, []);
  
  const fetchSites = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/sites/`);
      setSites(response.data);
      setError(null);
    } catch (err) {
      console.error('Error fetching sites:', err);
      setError('Помилка при завантаженні об\'єктів. Спробуйте пізніше.');
    } finally {
      setLoading(false);
    }
  };
  
  const handleDelete = async (siteCode) => {
    if (window.confirm(t('sites.confirmDelete', {siteCode}))) {
      try {
        await axios.delete(`${API_URL}/sites/${siteCode}`);
        fetchSites();
      } catch (err) {
        console.error('Error deleting site:', err);
        setError('Помилка при видаленні об\'єкту. Перевірте, чи немає з ним пов\'язаних ключів.');
      }
    }
  };
  
  const handleFilterChange = (e) => {
    setFilterValue(e.target.value);
  };
  
  const toggleRegExp = () => {
    setIsRegExp(!isRegExp);
  };
  
  const getFilteredSites = () => {
    if (!filterValue.trim()) return sites;
    
    try {
      if (isRegExp) {
        const regex = new RegExp(filterValue, 'i');
        return sites.filter(site => 
          regex.test(site.site_code) || 
          regex.test(site.address) ||
          regex.test(site.memo || '')
        );
      } else {
        const lowercaseFilter = filterValue.toLowerCase();
        return sites.filter(site => 
          site.site_code.toLowerCase().includes(lowercaseFilter) || 
          site.address.toLowerCase().includes(lowercaseFilter) ||
          (site.memo && site.memo.toLowerCase().includes(lowercaseFilter))
        );
      }
    } catch (err) {
      console.error('Error filtering sites:', err);
      return sites;
    }
  };
  
  const filteredSites = getFilteredSites();
  
  return (
    <Container>
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h1>{t('sites.title')}</h1>
        <Link to="/sites/add">
          <Button variant="primary">{t('sites.addSite')}</Button>
        </Link>
      </div>
      
      <Form.Group className="mb-3">
        <InputGroup>
          <Form.Control
            type="text"
            placeholder={t('sites.filter')}
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
          {isRegExp ? t('sites.filterMode.regexp') : t('sites.filterMode.simple')}
        </Form.Text>
      </Form.Group>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {loading ? (
        <p>{t('sites.loading')}</p>
      ) : filteredSites.length === 0 ? (
        <Alert variant="info">{t('sites.noSites')}</Alert>
      ) : (
        <Table striped bordered hover responsive>
          <thead>
            <tr>
              <th>{t('sites.columns.code')}</th>
              <th>{t('sites.columns.address')}</th>
              <th>{t('sites.columns.notes')}</th>
              <th>{t('sites.columns.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredSites.map((site) => (
              <tr key={site.site_id}>
                <td>{site.site_code}</td>
                <td>{site.address}</td>
                <td>{site.memo || '-'}</td>
                <td>
                  <Link to={`/sites/edit/${site.site_code}`} className="btn btn-sm btn-warning me-2">
                    {t('sites.actions.edit')}
                  </Link>
                  <Button 
                    variant="danger" 
                    size="sm" 
                    onClick={() => handleDelete(site.site_code)}
                  >
                    {t('sites.actions.delete')}
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Container>
  );
};

export default SitesList;
