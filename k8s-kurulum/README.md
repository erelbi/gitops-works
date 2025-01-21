# Sunucu Envanteri

        192.168.1.100 ansible
        192.168.1.10 k8s-master-node-1
        192.168.1.11 k8s-master-node-2
        192.168.1.12 k8s-master-node-3
        192.168.1.20 k8s-worker-node-1
        192.168.1.21 k8s-worker-node-2
        192.168.1.22 k8s-worker-node-3
        192.168.1.23 k8s-worker-node-4
        192.168.1.24 k8s-worker-node-5

# Ansible sunucusundan ssh keylerin atılması

- Ansible sunucusuna girin

        ssh 192.168.1.100

- SSH Anahtarının Oluşturulması:
Ansible sunucusunda bir SSH anahtarı yoksa, aşağıdaki komutla oluşturabilirsiniz:

        ssh-keygen -t rsa -b 4096

- SSh Anahtarlarının dağıtılması

        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.10
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.11
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.12
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.20
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.21
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.22
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.23
        ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.24

# Gerekli paketlerin kurulması

        apt install git python3-pip vim python3.11-venv curl -y

# Kubectl kurulum

        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Kurulum reposunu clonla

         cd && git clone https://gitlab.ozgur.com.tr/yazılım/k8s_projects/gitops/k8s-kurulum.git
         cd ~/k8s-kurulum/kubespray

# Gerekli python paketlerinin kurulması 

         python3 -m venv venv
         source venv/bin/activate
         pip3 install -r requirements.txt

# Kubernetes Kurulumu

        ansible-playbook -i inventory/test-ozgur/hosts.yml cluster.yml 
        mkdir ~/.kube
        scp 192.168.1.10:~/.kube/config ~/.kube/
        
- kubeconfig dosyasını açıp master ip adresini gir.

        vim ~/kube/config

# Gitops kurulumu Öncesi

- Nexusta npm, maven, docker vb repoları yoksa oluşturulması 
- Maven central reposunun nexus üzerinden proxylenmesi 
- Docker imajlarının nexus proxy üzerinden çekilebilmesi için docker hub, quay.io ve registry.k8s.io gibi belirli docker repolarının proxylenmesi. 

Not: aşağıdaki kullanıcıların şifresi değiştirilirse gitops reposundaki ilgili yerlerde güncellenmesi gerekir.

- gitlab'da kullanıcı açılması ve gitlab k8s grubuna maintainer olarak eklenmesi

        Kullanıcı : k8s-cicd
        Şifre: xxxxxxxxxx8txQxD

- gitlab k8s-cicd kullanıcısının api ve read_api yetkisine sahip access token oluşturulması. (flux kurulumunda kullanılacak.)

        xxxxx-xxxxxxxxxxxxxx1k

- nexus'da aşağıdaki kullanıcıları açıp k8s-cicd kullanıcısına bütün maven, npm, docker vs. repolarında admin yetkisi, k8s-cicd-read kullanıcısına docker read yetkisi verilmesi.

        Kullanıcı: k8s-cicd
        Şifre: xxxxxxxxxx8txQxD

        Kullanıcı: k8s-cicd-read 
        Şifre: ttt3RfunrsXo6KE

# flux-system

- Lokaline Flux CLI kurulumu:

        curl -s https://fluxcd.io/install.sh | sudo bash

- Flux kurulumu (yukarıda oluşturulan gitlab access token kullanılacak)

        flux bootstrap gitlab --hostname=gitlab.ozgur.com.tr --owner=yazılım/k8s_projects/gitops --repository=flux-test-ozgur --branch=main --deploy-token-auth --namespace flux-system

- Gitlab flux-test-ozgur reposu flux-system/gotk-sync.yaml dosyasındaki 10m yazan değeri 1m yap.

# K8s manifestlerinin Gitlaba atılması

- Dosyaların commit push yapılması

        cd && git clone https://gitlab.ozgur.com.tr/yazılım/k8s_projects/gitops/flux-test-ozgur.git
        cp -pr k8s-kurulum/manifests flux-test-ozgur/
        cd ~/flux-test-ozgur
        git config --global user.email "k8s-cd-cd@noreply.com"
        git config --global user.name "Takbis CI/CD"
        git add . && git commit -m "gitops resourceları init"
        git push

- Aşağıdaki çıktı daki gibi Applied Olarak görülmelidir.

        kubectl get kustomizations -A
        NAMESPACE     NAME          AGE    READY   STATUS
        flux-system   flux-system   5m9s   True    Applied revision: main@sha1:47efee404dc00ce0e3d9450c7964c25bea189f64

- jenkins deployları için oluşturulmuş service accountun tokenını al

        kubectl get secret jenkins-k8s-dev-token -n yazılım-k8s-dev -o jsonpath='{.data.token}'

- manifests/namespaces/jenkins/jenkins-robot-k8s-dev.yaml içerisine koy ve commitle

        cd ~/flux-test-ozgur
        vim manifests/namespaces/jenkins/jenkins-robot-k8s-dev.yaml
        git add . && git commit -m "jenkins token secret update."
        git push

- hata var mı kontrol

        watch kubectl get kustomizations -A

- Jenkins kullanıcı:

        jenkins-operator

- jenkins şifre:

        kubectl  get secrets jenkins-operator-credentials-jenkins -n jenkins  -o jsonpath='{.data.password}' | base64 --decode

# Vault Configurasyonu

- vault init 

        kubectl exec -it -n vault vault-0 -c vault -- sh  -c "vault operator init"

- Komutun çıktısını text editore al ve aşağıdaki dosyalarda ilgili yerleri çıktıya göre güncelle.

        cd ~/k8s-kurulum/vault
        vim vault-secrets.txt
        vim import.sh

- commit push 

        git add . && git commit -m "vault secrets update"
        git push

- import scriptini çalıştır.

        ./import.sh

- işlem tamamdır.

- Kontrol komutları

        kubectl get helmrepo -A
        kubectl get helmreleases -A 
